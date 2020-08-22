open Base
open Data_db_core

let ( let* ) = Lwt.bind

module Make (Config_ : Config_sig.SERVICE) (Log : Log_sig.SERVICE) :
  (* TODO use config service after exposing API using config service *)
Data_db_sig.SERVICE = struct
  let create_pool () =
    match !pool_ref with
    | Some pool ->
        Logs.debug (fun m ->
            m "DB: Skipping pool creation, re-using existing pool");
        Ok pool
    | None -> (
        let pool_size = Config.read_int ~default:10 "DATABASE_POOL_SIZE" in
        Logs.debug (fun m -> m "DB: Create pool with size %i" pool_size);
        "DATABASE_URL" |> Config.read_string |> Uri.of_string
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

  let lifecycle =
    Core.Container.Lifecycle.make "db"
      ~dependencies:[ Config_service.lifecycle ]
      (fun ctx -> ctx |> add_pool |> Lwt.return)
      (fun _ -> Lwt.return ())

  let safe_f f connection =
    try
      let* result = f connection in
      Lwt_result.return result
    with e ->
      let msg = Caml.Printexc.to_string e
      and stack = Caml.Printexc.get_backtrace () in
      let err_msg = Printf.sprintf "DB: %s%s\n" msg stack in
      let caqti_error =
        Caqti_error.request_failed ~uri:Uri.empty ~query:""
          (Caqti_error.Msg err_msg)
      in
      Lwt_result.fail caqti_error

  let query ctx f =
    match
      (Core_ctx.find ctx_key_connection ctx, Core_ctx.find ctx_key_pool ctx)
    with
    | Some connection, _ ->
        f connection
        |> Lwt_result.map_err (fun error ->
               let msg = Caqti_error.show error in
               Logs.err (fun m -> m "DB: %s" msg);
               msg)
        |> Lwt.map Result.ok_or_failwith
    | None, Some pool ->
        Caqti_lwt.Pool.use f pool
        |> Lwt_result.map_err (fun error ->
               let msg = Caqti_error.show error in
               Logs.err (fun m -> m "DB: %s" msg);
               msg)
        |> Lwt.map Result.ok_or_failwith
    | None, None ->
        Logs.err (fun m -> m "DB: No connection pool found");
        Logs.info (fun m -> m "DB: Have you applied the DB middleware?");
        failwith "DB: No connection pool found"

  let atomic ctx ?(no_rollback = false) f =
    let f = safe_f f in
    match Core_ctx.find ctx_key_pool ctx with
    | Some pool -> (
        let n_connections = Caqti_lwt.Pool.size pool in
        let max_connections =
          Config.read_int ~default:10 "DATABASE_POOL_SIZE"
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
                  let ctx_with_connection =
                    Core_ctx.add ctx_key_connection (module Connection) ctx
                  in
                  let* f_result = f ctx_with_connection in
                  let* commit_rollback_result =
                    match (f_result, no_rollback) with
                    | Error _, false ->
                        Connection.rollback ()
                        |> Lwt_result.map (fun res ->
                               Logs.debug (fun m ->
                                   m
                                     "DB TX: Successfully rolled back \
                                      transaction");
                               res)
                        |> Lwt_result.map_err (fun error ->
                               Logs.err (fun m ->
                                   m "DB TX: Failed to rollback transaction %s"
                                     (Caqti_error.show error));
                               error)
                    | Ok _, _ | _, true ->
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
        | Ok (Ok result) ->
            (* All good, return result of f ctx *)
            Lwt.return result
        | Ok (Error err) -> err |> Caqti_error.show |> failwith
        | Error pool_err ->
            (* Failed to start, commit or rollback transaction *)
            pool_err |> Caqti_error.show |> failwith )
    | None ->
        Logs.err (fun m -> m "No connection pool found");
        Logs.info (fun m -> m "Have you applied the DB middleware?");
        failwith "No connection pool found"

  let single_connection ctx f =
    let f = safe_f f in
    match Core_ctx.find ctx_key_pool ctx with
    | Some pool -> (
        let n_connections = Caqti_lwt.Pool.size pool in
        let max_connections =
          Config.read_int ~default:10 "DATABASE_POOL_SIZE"
        in
        Logs.debug (fun m ->
            m "DB: Pool usage: %i/%i" n_connections max_connections);
        let* pool_result =
          Caqti_lwt.Pool.use
            (fun connection ->
              Logs.debug (fun m -> m "DB: Fetched connection pool from context");
              let (module Connection : Caqti_lwt.CONNECTION) = connection in
              let ctx_with_connection =
                Core_ctx.add ctx_key_connection (module Connection) ctx
              in
              f ctx_with_connection |> Lwt.map Result.return)
            pool
        in
        Logs.debug (fun m -> m "DB: Putting back connection to pool");
        match pool_result with
        | Ok (Ok result) ->
            (* All good, return result of f ctx *)
            Lwt.return result
        | Ok (Error err) -> err |> Caqti_error.show |> failwith
        | Error pool_err ->
            (* Failed to start, commit or rollback transaction *)
            pool_err |> Caqti_error.show |> failwith )
    | None ->
        Logs.err (fun m -> m "No connection pool found");
        Logs.info (fun m -> m "Have you applied the DB middleware?");
        failwith "No connection pool found"

  let set_fk_check_request =
    Caqti_request.exec Caqti_type.bool
      {sql|
        SET FOREIGN_KEY_CHECKS = ?;
           |sql}

  let set_fk_check ctx ~check =
    query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec set_fk_check_request check)
end
