open! Core
open Opium.Std

let ( let* ) = Lwt_result.bind

(* Type aliases for the sake of documentation and explication *)
type 'err caqti_conn_pool =
  (Caqti_lwt.connection, ([> Caqti_error.connect ] as 'err)) Caqti_lwt.Pool.t

type ('res, 'err) query =
  Caqti_lwt.connection -> ('res, ([< Caqti_error.t ] as 'err)) result Lwt.t

type 'a db_result = ('a, Caqti_error.t) Lwt_result.t

type connection = (module Caqti_lwt.CONNECTION)

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
         let _ = Lwt_io.printf "failed to clean repository msg=%s" error in
         error)

(* let query_pool_with_trx query pool =
 *   query_pool
 *     (fun connection ->
 *       let (module Connection : Caqti_lwt.CONNECTION) = connection in
 *       let* () = Connection.start () in
 *       let* result = query connection in
 *       let* () = Connection.commit () in
 *       Lwt.return @@ Ok result)
 *     pool *)

(* Seal the key type with a non-exported type, so the pool cannot be retrieved
   outside of this module *)

type db_connection = (module Caqti_lwt.CONNECTION)

let key : db_connection Opium.Hmap.key =
  Opium.Hmap.Key.create
    ("db connection", fun _ -> sexp_of_string "db_connection")

let middleware app =
  let ( let* ) = Lwt.bind in
  let pool = connect () in
  let filter (handler : Request.t -> Response.t Lwt.t) (req : Request.t) =
    let response_ref : Response.t Lwt.t option ref = ref None in
    let result =
      Caqti_lwt.Pool.use
        (fun connection ->
          let (module Connection : Caqti_lwt.CONNECTION) = connection in
          let env = Opium.Hmap.add key connection (Request.env req) in
          let response = handler { req with env } in
          (* we wait for the handler to finish before finally returning the connection to the pool *)
          let* _ = response in
          let _ = response_ref := Some response in
          (* all errors are handled when querying the db and in the actual handlers *)
          (* TODO log all errors before returning Ok () *)
          Lwt.return @@ Ok ())
        pool
    in
    Lwt.bind result (fun _ ->
        match !response_ref with
        | Some response -> response
        | None -> failwith "error happened")
  in
  let m = Rock.Middleware.create ~name:"database connection" ~filter in
  Opium.Std.middleware m app

(* Execute a query on the database connection stored in the request
   environment *)
let query_db request query =
  Request.env request |> Opium.Hmap.get key |> query
  |> Lwt_result.map_err Caqti_error.show

module Migrate = struct
  type migration_error = Caqti_error.t

  type migration_operation =
    Caqti_lwt.connection -> unit -> (unit, migration_error) result Lwt.t

  type migration_step = string * migration_operation

  type migration = string * migration_step list

  module State = struct
    module Model = struct
      type t = { namespace : string; version : int; dirty : bool }
      [@@deriving fields]

      let create ~namespace = { namespace; version = 0; dirty = true }

      let mark_dirty state = { state with dirty = true }

      let mark_clean state = { state with dirty = false }

      let increment state = { state with version = state.version + 1 }

      let steps_to_apply (namespace, steps) { version; _ } =
        (namespace, List.drop steps version)
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
) ON CONFLICT (namespace)
DO UPDATE SET version = %int{version},
dirty = %bool{dirty}
|sql}
            record_in]
    end

    module Service = struct
      let setup pool =
        query_pool (fun c -> Repository.create_table_if_not_exists c ()) pool

      let has pool ~namespace =
        let* result = query_pool (fun c -> Repository.get c ~namespace) pool in
        Lwt_result.return (Option.is_some result)

      let get pool ~namespace =
        let* state = query_pool (fun c -> Repository.get c ~namespace) pool in
        Lwt.return
        @@
        match state with
        | Some state -> Ok state
        | None ->
            Error
              (Printf.sprintf "could not get migration state for namespace=%s"
                 namespace)

      let upsert pool state =
        query_pool (fun c -> Repository.upsert c state) pool

      let mark_dirty pool ~namespace =
        let* state = get pool ~namespace in
        let dirty_state = Model.mark_dirty state in
        let* () = upsert pool dirty_state in
        Lwt.return @@ Ok dirty_state

      let mark_clean pool ~namespace =
        let* state = get pool ~namespace in
        let clean_state = Model.mark_clean state in
        let* () = upsert pool clean_state in
        Lwt.return @@ Ok clean_state

      let increment pool ~namespace =
        let* state = get pool ~namespace in
        let updated_state = Model.increment state in
        let* () = upsert pool updated_state in
        Lwt.return @@ Ok updated_state
    end
  end

  let execute_steps migration pool =
    let namespace, steps = migration in
    let open Lwt in
    let rec run steps pool =
      match steps with
      | [] -> Lwt_result.return ()
      | (name, query) :: steps -> (
          Lwt_io.printf "Running: %s\n" name >>= fun () ->
          query_pool (fun c -> query c ()) pool >>= function
          | Ok () ->
              let* _ = State.Service.increment pool ~namespace in
              run steps pool
          | Error err ->
              Lwt_io.printf "error while running migration for %s msg=%s"
                namespace err
              >>= fun () -> return (Error err) )
    in
    ( match List.length steps with
    | 0 -> Lwt_io.printf "no migrations to apply for %s\n" namespace
    | n -> Lwt_io.printf "applying %i migrations for %s\n" n namespace )
    >>= fun () -> run steps pool

  let execute_migration migration pool =
    let namespace, _ = migration in
    let* () = State.Service.setup pool in
    let* has_state = State.Service.has pool ~namespace in
    let* state =
      if has_state then
        let* state = State.Service.get pool ~namespace in
        if State.Model.dirty state then
          Lwt.return
          @@ Error
               (Printf.sprintf
                  "dirty migration found for namespace %s, please fix manually"
                  namespace)
        else State.Service.mark_dirty pool ~namespace
      else
        let state = State.Model.create ~namespace in
        let* () = State.Service.upsert pool state in
        Lwt.return @@ Ok state
    in
    let migration_to_apply = State.Model.steps_to_apply migration state in
    let* () = execute_steps migration_to_apply pool in
    let* _ = State.Service.mark_clean pool ~namespace in
    Lwt.return @@ Ok ()

  let execute migrations =
    let open Lwt in
    let rec run migrations pool =
      match migrations with
      | [] -> Lwt_result.return ()
      | migration :: migrations -> (
          execute_migration migration pool >>= function
          | Ok () -> run migrations pool
          | Error err -> return (Error err) )
    in
    return (connect ()) >>= run migrations
end
