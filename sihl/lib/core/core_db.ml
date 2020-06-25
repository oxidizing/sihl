(* DatabaseService *)

let ( let* ) = Lwt_result.bind

open Base

type pool = (Caqti_lwt.connection, Caqti_error.t) Caqti_lwt.Pool.t

let ctx_key_pool : pool Core_ctx.key = Core_ctx.create_key ()

let ctx_add_pool pool ctx = Core_ctx.add ctx_key_pool pool ctx

type connection = (module Caqti_lwt.CONNECTION)

let ctx_key_connection : connection Core_ctx.key = Core_ctx.create_key ()

let middleware_key_connection : connection Opium.Hmap.key =
  Opium.Hmap.Key.create ("connection", fun _ -> sexp_of_string "connection")

let create_pool () =
  let pool_size = Core_config.read_int ~default:10 "DATABASE_POOL_SIZE" in
  Logs.debug (fun m -> m "DB: Create pool with size %i" pool_size);
  "DATABASE_URL" |> Core_config.read_string |> Uri.of_string
  |> Caqti_lwt.connect_pool ~max_size:pool_size
  |> function
  | Ok pool -> Ok pool
  | Error err ->
      let msg = "DB: Failed to connect to DB pool" in
      Logs.err (fun m -> m "%s %s" msg (Caqti_error.show err));
      Error msg

let ctx_with_pool () =
  let pool = create_pool () |> Result.ok_or_failwith in
  Core_ctx.(empty |> ctx_add_pool pool)

let query_connection conn f = f conn |> Lwt_result.map_err Caqti_error.show

let query ctx f =
  match Core_ctx.find ctx_key_pool ctx with
  | Some pool ->
      (* TODO rollback in case of error *)
      Caqti_lwt.Pool.use
        (fun connection ->
          f connection
          |> Lwt_result.map_err (fun msg ->
                 Caqti_error.request_failed ~uri:Uri.empty ~query:""
                   (Caqti_error.Msg msg)))
        pool
      |> Lwt_result.map_err Caqti_error.show
  | None ->
      Lwt.return
        (Error "No connection pool found, have you applied the DB middleware?")

let trx ctx f =
  match Core_ctx.find ctx_key_pool ctx with
  | Some pool ->
      (* TODO rollback in case of error *)
      Caqti_lwt.Pool.use
        (fun connection ->
          (let (module Connection : Caqti_lwt.CONNECTION) = connection in
           let* () =
             Connection.start () |> Lwt_result.map_err Caqti_error.show
           in
           let ctx = Core_ctx.add ctx_key_connection (module Connection) ctx in
           let* result = f ctx in
           let* () =
             Connection.commit () |> Lwt_result.map_err Caqti_error.show
           in
           Lwt.return @@ Ok result)
          |> Lwt_result.map_err (fun msg ->
                 Caqti_error.request_failed ~uri:Uri.empty ~query:""
                   (Caqti_error.Msg msg)))
        pool
      |> Lwt_result.map_err Caqti_error.show
  | None ->
      Lwt.return
        (Error "No connection pool found, have you applied the DB middleware?")

let set_fk_check conn ~check =
  let module Connection = (val conn : Caqti_lwt.CONNECTION) in
  let request =
    Caqti_request.exec Caqti_type.bool
      {sql|
        SET FOREIGN_KEY_CHECKS = ?;
           |sql}
  in
  Connection.exec request check |> Lwt_result.map_err Caqti_error.show
