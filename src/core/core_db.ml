(* DatabaseService *)

open Base

type pool = (Caqti_lwt.connection, Caqti_error.t) Caqti_lwt.Pool.t

let ctx_key_pool : pool Core_ctx.key = Core_ctx.create_key ()

let ctx_add_pool pool ctx = Core_ctx.add ctx_key_pool pool ctx

type connection = (module Caqti_lwt.CONNECTION)

let ctx_key_connection : connection Core_ctx.key = Core_ctx.create_key ()

let middleware_key_connection : connection Opium.Hmap.key =
  Opium.Hmap.Key.create ("connection", fun _ -> sexp_of_string "connection")

let pool_ref : pool option ref = ref None

let create_pool () =
  match !pool_ref with
  | Some pool ->
      Logs.debug (fun m ->
          m "DB: Skipping pool creation, re-using existing pool");
      Ok pool
  | None -> (
      let pool_size = Core_config.read_int ~default:10 "DATABASE_POOL_SIZE" in
      Logs.debug (fun m -> m "DB: Create pool with size %i" pool_size);
      "DATABASE_URL" |> Core_config.read_string |> Uri.of_string
      |> Caqti_lwt.connect_pool ~max_size:pool_size
      |> function
      | Ok pool ->
          pool_ref := Some pool;
          Ok pool
      | Error err ->
          let msg = "DB: Failed to connect to DB pool" in
          Logs.err (fun m -> m "%s %s" msg (Caqti_error.show err));
          Error msg )

let ctx_with_pool () =
  let pool = create_pool () |> Result.ok_or_failwith in
  Core_ctx.(empty |> ctx_add_pool pool)

let add_pool ctx =
  let pool = create_pool () |> Result.ok_or_failwith in
  ctx_add_pool pool ctx

let query_connection conn f = f conn |> Lwt_result.map_err Caqti_error.show

let query ctx f =
  match
    (Core_ctx.find ctx_key_connection ctx, Core_ctx.find ctx_key_pool ctx)
  with
  | Some connection, _ ->
      Logs.debug (fun m ->
          m "DB TX: Open transaction found, running queries on tx connection");
      f connection
  | None, Some pool ->
      Caqti_lwt.Pool.use
        (fun connection ->
          f connection
          |> Lwt_result.map_err (fun msg ->
                 Caqti_error.request_failed ~uri:Uri.empty ~query:""
                   (Caqti_error.Msg msg)))
        pool
      |> Lwt_result.map_err (fun error ->
             let msg = Caqti_error.show error in
             Logs.err (fun m -> m "DB: %s" msg);
             msg)
  | None, None ->
      Logs.err (fun m -> m "DB: No connection pool found");
      Logs.info (fun m -> m "DB: Have you applied the DB middleware?");
      Lwt.return (Error "DB: No connection pool found")

let atomic ctx f =
  let ( let* ) = Lwt.bind in
  match Core_ctx.find ctx_key_pool ctx with
  | Some pool -> (
      let n_connections = Caqti_lwt.Pool.size pool in
      let max_connections =
        Core_config.read_int ~default:10 "DATABASE_POOL_SIZE"
      in
      Logs.debug (fun m ->
          m "DB: Pool usage: %i/%i" n_connections max_connections);
      Logs.debug (fun m -> m "DB TX: Fetched connection pool from context");
      let* pool_result =
        Caqti_lwt.Pool.use
          (fun connection ->
            Logs.debug (fun m -> m "DB TX: Fetched connection from pool");
            let (module Connection : Caqti_lwt.CONNECTION) = connection in
            let* start_result = Connection.start () in
            match start_result with
            | Error msg ->
                Logs.debug (fun m ->
                    m "DB TX: Failed to start transaction %s"
                      (Caqti_error.show msg));
                Lwt.return @@ Error msg
            | Ok () ->
                Logs.debug (fun m -> m "DB TX: Started transaction");
                let ctx =
                  Core_ctx.add ctx_key_connection (module Connection) ctx
                in
                let* f_result = f ctx in
                let _ = Core_ctx.remove ctx_key_connection ctx in
                let* commit_rollback_result =
                  match f_result with
                  | Error _ ->
                      Connection.rollback ()
                      |> Lwt_result.map (fun res ->
                             Logs.debug (fun m ->
                                 m "DB TX: Successfully rolled back transaction");
                             res)
                      |> Lwt_result.map_err (fun error ->
                             Logs.err (fun m ->
                                 m "DB TX: Failed to rollback transaction %s"
                                   (Caqti_error.show error));
                             error)
                  | Ok _ ->
                      Connection.commit ()
                      |> Lwt_result.map (fun res ->
                             Logs.debug (fun m ->
                                 m "DB TX: Successfully committed transaction");
                             res)
                      |> Lwt_result.map_err (fun error ->
                             Logs.err (fun m ->
                                 m "DB TX: Failed to commit transaction %s"
                                   (Caqti_error.show error));
                             error)
                in
                Lwt.return commit_rollback_result
                |> Lwt_result.map (fun _ -> f_result))
          pool
      in
      match pool_result with
      | Ok result_ok ->
          (* All good, return result of f ctx *)
          result_ok |> Result.return |> Lwt.return
      | Error pool_err ->
          (* Failed to start, commit or rollback transaction *)
          Caqti_error.show pool_err |> Result.fail |> Lwt.return )
  | None ->
      Logs.err (fun m -> m "No connection pool found");
      Logs.info (fun m -> m "Have you applied the DB middleware?");
      Lwt.return (Error "No connection pool found")

let set_fk_check conn ~check =
  let module Connection = (val conn : Caqti_lwt.CONNECTION) in
  let request =
    Caqti_request.exec Caqti_type.bool
      {sql|
        SET FOREIGN_KEY_CHECKS = ?;
           |sql}
  in
  Connection.exec request check |> Lwt_result.map_err Caqti_error.show
