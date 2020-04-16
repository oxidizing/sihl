open! Core
open Opium.Std

(* Type aliases for the sake of documentation and explication *)
type 'err caqti_conn_pool =
  (Caqti_lwt.connection, ([> Caqti_error.connect ] as 'err)) Caqti_lwt.Pool.t

type ('res, 'err) query =
  Caqti_lwt.connection -> ('res, ([< Caqti_error.t ] as 'err)) result Lwt.t

(** Configuration of the connection *)
let url = "localhost"

let user = "admin"

let password = "password"

let port = 5432

let database = "dev"

let connection_uri =
  Printf.sprintf "postgresql://%s:%s@%s:%i/%s" user password url port database

(* [connection ()] establishes a live database connection and is a pool of
   concurrent threads for accessing that connection. *)
let connect () =
  connection_uri |> Uri.of_string |> Caqti_lwt.connect_pool ~max_size:10
  |> function
  | Ok pool -> pool
  | Error err -> failwith (Caqti_error.show err)

(* [query_pool query pool] is the [Ok res] of the [res] obtained by executing
   the database [query], or else the [Error err] reporting the error causing
   the query to fail. *)
let query_pool query pool =
  Caqti_lwt.Pool.use query pool |> Lwt_result.map_err Caqti_error.show

(* Seal the key type with a non-exported type, so the pool cannot be retrieved
   outside of this module *)
type 'err db_pool = 'err caqti_conn_pool

let key : _ db_pool Opium.Hmap.key =
  Opium.Hmap.Key.create ("db pool", fun _ -> sexp_of_string "db_pool")

(* Initiate a connection pool and add it to the app environment *)
let middleware app =
  let pool = connect () in
  let filter handler (req : Request.t) =
    let env = Opium.Hmap.add key pool (Request.env req) in
    handler { req with env }
  in
  let m = Rock.Middleware.create ~name:"database connection pool" ~filter in
  middleware m app

(* Execute a query on the database connection pool stored in the request
   environment *)
let query_db query req =
  Request.env req |> Opium.Hmap.get key |> query_pool query

module Migration = struct
  type 'a migration_error =
    [< Caqti_error.t > `Connect_failed `Connect_rejected `Post_connect ] as 'a

  type 'a migration_operation =
    Caqti_lwt.connection -> unit -> (unit, 'a migration_error) result Lwt.t

  type 'a migration_step = string * 'a migration_operation

  let execute migrations =
    let open Lwt in
    let rec run migrations pool =
      match migrations with
      | [] -> Lwt_result.return ()
      | (name, migration) :: migrations -> (
          Lwt_io.printf "Running: %s\n" name >>= fun () ->
          query_pool (fun c -> migration c ()) pool >>= function
          | Ok () -> run migrations pool
          | Error err ->
              Lwt_io.printf "Failed to run migration msg=%s" err >>= fun () ->
              return (Error err) )
    in
    return (connect ()) >>= run migrations

  (* let run migrations =
   *   match Lwt_main.run (execute migrations) with
   *   | Ok () -> print_endline "Migration complete"
   *   | Error err -> failwith err *)
end

(* let clean queries =
 *   let open Lwt in
 *   let rec run queries pool =
 *     match queries with
 *     | [] -> Lwt_result.return ()
 *     | query :: queries -> (
 *         query_pool (fun c -> query c ()) pool >>= function
 *         | Ok () -> run queries pool
 *         | Error err -> return (Error err) )
 *   in
 *   return (connect ()) >>= run queries *)
