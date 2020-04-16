open! Core
open Opium.Std

let ( let* ) = Lwt.bind

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
  module State = struct
    module Model = struct
      type t = { namespace : string; version : int; dirty : bool }
      [@@deriving fields]

      let create ~namespace = { namespace; version = 0; dirty = false }
    end

    module Repository = struct
      open Model

      let create_table_if_not_exists =
        [%rapper
          execute
            {sql|
CREATE TABLE IF NOT EXISTS core_migration_state (
  namespace VARCHAR(128) NOT NULL,
  version INTEGER,
  dirty BOOL,
  UNIQUE (namespace)
);
 |sql}]

      let get =
        [%rapper
          get_opt
            {sql|
SELECT
  @string{namespace},
  @int{version},
  @bool{dirty}
FROM core_migration_state
WHERE namespace = %string{namespace};
|sql}
            record_out]

      let upsert =
        [%rapper
          execute
            {sql|
INSERT INTO core_migration_state (
  namespace,
  version,
  dirty
) VALUES (
  %string{namespace},
  %int{version},
  %bool{dirty}
) ON CONFLICT (namespace) DO UPDATE SET version = %int{version},
                                        dirty = %bool{dirty}
|sql}
            record_in]
    end

    module Service = struct
      let error_to_exn result =
        match result with
        | Ok result -> result
        | Error msg -> Fail.raise_database msg

      let setup pool =
        let* result =
          query_pool (fun c -> Repository.create_table_if_not_exists c ()) pool
        in
        result |> error_to_exn |> Lwt.return

      let has pool ~namespace =
        let* result = query_pool (fun c -> Repository.get c ~namespace) pool in
        Lwt.return
        @@
        match result with
        | Ok (Some _) -> true
        | Ok None -> false
        | Error msg -> Fail.raise_database msg

      let get pool ~namespace =
        let* state = query_pool (fun c -> Repository.get c ~namespace) pool in
        Lwt.return
        @@
        match state with
        | Ok (Some state) -> state
        | Ok None ->
            Fail.raise_database
              (Printf.sprintf "could not get migration state for namespace=%s"
                 namespace)
        | Error msg -> Fail.raise_database msg

      let upsert pool state =
        let* result = query_pool (fun c -> Repository.upsert c state) pool in
        let _ = result |> error_to_exn in
        Lwt.return state
    end
  end

  type 'a migration_error =
    [< Caqti_error.t > `Connect_failed `Connect_rejected `Post_connect ] as 'a

  type 'a migration_operation =
    Caqti_lwt.connection -> unit -> (unit, 'a migration_error) result Lwt.t

  type 'a migration_step = string * 'a migration_operation

  type 'a migration = string * 'a migration_step list

  let execute_steps steps pool =
    let open Lwt in
    let rec run steps pool =
      match steps with
      | [] -> Lwt_result.return ()
      | (name, query) :: steps -> (
          Lwt_io.printf "Running: %s\n" name >>= fun () ->
          query_pool (fun c -> query c ()) pool >>= function
          | Ok () -> run steps pool
          | Error err -> return (Error err) )
    in
    run steps pool

  let execute_migration migration pool =
    let namespace, steps = migration in
    let* () = State.Service.setup pool in
    let* has_state = State.Service.has pool ~namespace in

    if has_state then State.Service.get pool ~namespace
    else
      let state = State.Model.create ~namespace in
      State.Service.upsert pool state

  (* TODO
     setup table
     check if there is a state
     if there is one, mark as dirty
     get migrations to apply and new version
     apply migration steps
     update state version and set dirty = false
  *)

  let _ = execute_steps [] pool

  let execute migrations =
    let open Lwt in
    let rec run migrations pool =
      match migrations with
      | [] ->
          Lwt_io.printf "no migrations found, nothing to do\n" >>= fun () ->
          Lwt_result.return ()
      | migration :: migrations -> (
          execute_migration migration pool >>= function
          | Ok () -> run migrations pool
          | Error err -> return (Error err) )
    in
    return (connect ()) >>= run migrations
end
