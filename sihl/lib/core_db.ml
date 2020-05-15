open Base
open Opium.Std

let ( let* ) = Lwt_result.bind

(* Type aliases for the sake of documentation and explication *)
type 'err caqti_conn_pool =
  (Caqti_lwt.connection, ([> Caqti_error.connect ] as 'err)) Caqti_lwt.Pool.t

type ('res, 'err) query =
  Caqti_lwt.connection -> ('res, ([< Caqti_error.t ] as 'err)) Result.t Lwt.t

type 'a db_result = ('a, Caqti_error.t) Lwt_result.t

type connection = (module Caqti_lwt.CONNECTION)

(* [connection ()] establishes a live database connection and is a pool of
   concurrent threads for accessing that connection. *)
let connect () =
  let pool_size = Core_config.read_int ~default:10 "DATABASE_POOL_SIZE" in
  "DATABASE_URL" |> Core_config.read_string |> Uri.of_string
  |> Caqti_lwt.connect_pool ~max_size:pool_size
  |> function
  | Ok pool -> pool
  | Error err -> Core_err.raise_database (Caqti_error.show err)

(* [query_pool query pool] is the [Ok res] of the [res] obtained by executing
   the database [query], or else the [Error err] reporting the error causing
   the query to fail. *)
let query_pool query pool =
  Caqti_lwt.Pool.use query pool |> Lwt_result.map_err Caqti_error.show

let clean queries =
  let pool = connect () in
  let rec run_clean queries pool =
    match queries with
    | [] -> Lwt_result.return ()
    | query :: queries ->
        let* _ = query_pool query pool in
        run_clean queries pool
  in
  run_clean queries pool
  |> Lwt_result.map_err (fun error ->
         let _ =
           Logs.err (fun m -> m "failed to clean repository msg=%s" error)
         in
         error)

(* Seal the key type with a non-exported type, so the pool cannot be retrieved
   outside of this module *)

type db_connection = (module Caqti_lwt.CONNECTION)

let key : db_connection Opium.Hmap.key =
  Opium.Hmap.Key.create
    ("db connection", fun _ -> sexp_of_string "db_connection")

let request_with_connection request =
  let ( let* ) = Lwt.bind in
  let* connection =
    "DATABASE_URL" |> Core_config.read_string |> Uri.of_string |> Caqti_lwt.connect
  in
  let connection =
    connection |> function
    | Ok connection -> connection
    | Error err -> Core_err.raise_database (Caqti_error.show err)
  in
  let env = Opium.Hmap.add key connection (Request.env request) in
  Lwt.return @@ { request with env }

let middleware () app =
  let ( let* ) = Lwt.bind in
  let pool = connect () in
  let filter handler req =
    let response_ref : Response.t option ref = ref None in
    let* _ =
      Caqti_lwt.Pool.use
        (fun connection ->
          let (module Connection : Caqti_lwt.CONNECTION) = connection in
          let env = Opium.Hmap.add key connection (Request.env req) in
          let response = handler { req with env } in
          let* response = response in
          (* using a ref here is dangerous because we might escape the scope of
             the pool handler. we wait for the response, so all db handling is
             done here *)
          let _ = response_ref := Some response in
          Lwt.return @@ Ok ())
        pool
    in
    match !response_ref with
    | Some response -> Lwt.return response
    | None -> Core_err.raise_database "error happened"
  in
  let m = Rock.Middleware.create ~name:"database connection" ~filter in
  Opium.Std.middleware m app

(* TODO a transaction should return a request and not a connection so it nicely composes with other service calls *)
let query_db_with_trx request query =
  let ( let* ) = Lwt.bind in
  let connection = request |> Request.env |> Opium.Hmap.get key in
  let (module Connection : Caqti_lwt.CONNECTION) = connection in
  let* start_result = Connection.start () in
  let () =
    match start_result with
    | Ok _ -> ()
    | Error error ->
        Logs.err (fun m ->
            m "failed to start transaction %s" (Caqti_error.show error));
        Core_err.raise_database
          "failed to start transaction %s (Caqti_error.show error)"
  in
  let* result = query connection in
  let* trx_result =
    match result with
    | Ok _ ->
        Logs.info (fun m -> m "committing connection");
        Connection.commit ()
    | Error error ->
        Logs.warn (fun m ->
            m "failed to run transaction, rolling back %s"
              (Caqti_error.show error));
        Connection.rollback ()
  in
  let () =
    match trx_result with
    | Ok _ -> ()
    | Error _ -> Core_err.raise_database "failed to commit or rollback transaction"
  in
  result |> Result.map_error ~f:Caqti_error.show |> Lwt.return

let query_db_with_trx_exn request query =
  Lwt.map
    (Core_err.with_database "failed to query with transaction")
    (query_db_with_trx request query)

let query_db request query =
  Request.env request |> Opium.Hmap.get key |> query
  |> Lwt_result.map_err Caqti_error.show

let query_db_exn ?message request query =
  let open Lwt.Infix in
  query_db request query >>= fun result ->
  match result with
  | Ok result -> Lwt.return result
  | Error msg -> Core_err.raise_database (Option.value ~default:msg message)
