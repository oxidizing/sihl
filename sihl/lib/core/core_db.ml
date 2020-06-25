(* DatabaseService *)

open Base
open Opium.Std

type pool = (Caqti_lwt.connection, Caqti_error.t) Caqti_lwt.Pool.t

let ctx_key_pool : pool Core_ctx.key = Core_ctx.create_key ()

let ctx_add_pool pool ctx = Core_ctx.add ctx_key_pool pool ctx

type ('res, 'err) query =
  Caqti_lwt.connection -> ('res, ([< Caqti_error.t ] as 'err)) Result.t Lwt.t

type 'a db_result = ('a, Caqti_error.t) Lwt_result.t

type 'a result = ('a, string) Lwt_result.t

type connection = (module Caqti_lwt.CONNECTION)

let ctx_key_connection : connection Core_ctx.key = Core_ctx.create_key ()

let connect () =
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

type db_connection = (module Caqti_lwt.CONNECTION)

(* TODO move key including query_db ... functions to db middleware *)
let key : db_connection Opium.Hmap.key =
  Opium.Hmap.Key.create
    ("db connection", fun _ -> sexp_of_string "db_connection")

let request_with_connection request =
  let ( let* ) = Lwt.bind in
  let* connection =
    "DATABASE_URL" |> Core_config.read_string |> Uri.of_string
    |> Caqti_lwt.connect
  in
  let connection =
    connection |> function
    | Ok connection -> connection
    | Error err -> Core_err.raise_database (Caqti_error.show err)
  in
  let env = Opium.Hmap.add key connection (Request.env request) in
  Lwt.return @@ { request with env }

(* TODO a transaction should return a request and not a connection so it nicely composes with other service calls *)
(* TODO implement transactions properly *)
(* let query_db_with_trx request query =
 *   let ( let* ) = Lwt.bind in
 *   let connection =
 *     match request |> Request.env |> Opium.Hmap.find key with
 *     | Some connection -> Lwt.return @@ Ok connection
 *     | None ->
 *         let msg =
 *           "DB: Failed to fetch DB connection from Request.env, was the DB \
 *            middleware applied?"
 *         in
 *         Logs.err (fun m -> m "%s" msg);
 *         Lwt.return @@ Error msg
 *   in
 *   let (module Connection : Caqti_lwt.CONNECTION) = connection in
 *   let* start_result = Connection.start () in
 *   let () =
 *     match start_result with
 *     | Ok _ -> ()
 *     | Error error ->
 *         Logs.err (fun m ->
 *             m "failed to start transaction %s" (Caqti_error.show error));
 *         Core_err.raise_database
 *           "failed to start transaction %s (Caqti_error.show error)"
 *   in
 *   let* result = query connection in
 *   let* trx_result =
 *     match result with
 *     | Ok _ ->
 *         Logs.info (fun m -> m "committing connection");
 *         Connection.commit ()
 *     | Error error ->
 *         Logs.warn (fun m ->
 *             m "failed to run transaction, rolling back %s"
 *               (Caqti_error.show error));
 *         Connection.rollback ()
 *   in
 *   let () =
 *     match trx_result with
 *     | Ok _ -> ()
 *     | Error _ ->
 *         Core_err.raise_database "failed to commit or rollback transaction"
 *   in
 *   result |> Result.map_error ~f:Caqti_error.show |> Lwt.return
 *
 * let query_db_with_trx_exn request query =
 *   Lwt.map
 *     (Core_err.with_database "failed to query with transaction")
 *     (query_db_with_trx request query) *)

(* TODO deprecate this *)
let query_db request query =
  match request |> Request.env |> Opium.Hmap.find key with
  | Some connection ->
      connection |> query |> Lwt_result.map_err Caqti_error.show
  | None ->
      let msg =
        "DB: Failed to fetch DB connection from Request.env, was the DB \
         middleware applied?"
      in
      Logs.err (fun m -> m "%s" msg);
      Lwt.return @@ Error msg

let query request query =
  match request |> Request.env |> Opium.Hmap.find key with
  | Some connection -> connection |> query
  | None ->
      let msg =
        "DB: Failed to fetch DB connection from Request.env, was the DB \
         middleware applied?"
      in
      Logs.err (fun m -> m "%s" msg);
      Lwt.return @@ failwith msg

let query_db_connection connection query =
  query connection |> Lwt_result.map_err Caqti_error.show

let query_db_exn ?message request query =
  let open Lwt.Infix in
  query_db request query >>= fun result ->
  match result with
  | Ok result -> Lwt.return result
  | Error msg -> Core_err.raise_database (Option.value ~default:msg message)

let ( let* ) = Lwt_result.bind

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
