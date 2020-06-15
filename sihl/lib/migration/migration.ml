open Base

let ( let* ) = Lwt_result.bind

module Model = struct
  type t = { namespace : string; version : int; dirty : bool }

  let create ~namespace = { namespace; version = 0; dirty = true }

  let mark_dirty state = { state with dirty = true }

  let mark_clean state = { state with dirty = false }

  let increment state = { state with version = state.version + 1 }

  let steps_to_apply (namespace, steps) { version; _ } =
    (namespace, List.drop steps version)

  let of_tuple (namespace, version, dirty) = { namespace; version; dirty }

  let to_tuple state = (state.namespace, state.version, state.dirty)

  let dirty state = state.dirty
end

module type SERVICE = sig
  val setup : Core.Db.connection -> (unit, string) Lwt_result.t

  val has :
    Core.Db.connection -> namespace:string -> (bool, string) Lwt_result.t

  val get :
    Core.Db.connection -> namespace:string -> (Model.t, string) Lwt_result.t

  val upsert : Core.Db.connection -> Model.t -> (unit, string) Lwt_result.t

  val mark_dirty :
    Core.Db.connection -> namespace:string -> (Model.t, string) Lwt_result.t

  val mark_clean :
    Core.Db.connection -> namespace:string -> (Model.t, string) Lwt_result.t

  val increment :
    Core.Db.connection -> namespace:string -> (Model.t, string) Lwt_result.t
end

let key : (module SERVICE) Core_registry.Key.t =
  Core_registry.Key.create "migration.service"

module type REPO = sig
  val create_table_if_not_exists :
    Core.Db.connection ->
    (unit, [> Caqti_error.call_or_retrieve ]) Result.t Lwt.t

  val get :
    Core.Db.connection ->
    namespace:string ->
    (Model.t option, [> Caqti_error.call_or_retrieve ]) Result.t Lwt.t

  val upsert :
    Core.Db.connection ->
    state:Model.t ->
    (unit, [> Caqti_error.call_or_retrieve ]) Result.t Lwt.t
end

module Make (Repo : REPO) : SERVICE = struct
  let setup c =
    Logs.debug (fun m -> m "MIGRATION: Setting up table if not exists");
    Repo.create_table_if_not_exists |> Core.Db.query_db_connection c

  let has c ~namespace =
    let* result = Repo.get ~namespace |> Core.Db.query_db_connection c in
    Lwt_result.return (Option.is_some result)

  let get c ~namespace =
    let* state = Repo.get ~namespace |> Core.Db.query_db_connection c in
    Lwt.return
    @@
    match state with
    | Some state -> Ok state
    | None ->
        Error
          (Printf.sprintf "could not get migration state for namespace %s"
             namespace)

  let upsert c state = Repo.upsert ~state |> Core.Db.query_db_connection c

  let mark_dirty c ~namespace =
    let* state = get c ~namespace in
    let dirty_state = Model.mark_dirty state in
    let* () = upsert c dirty_state in
    Lwt.return @@ Ok dirty_state

  let mark_clean c ~namespace =
    let* state = get c ~namespace in
    let clean_state = Model.mark_clean state in
    let* () = upsert c clean_state in
    Lwt.return @@ Ok clean_state

  let increment c ~namespace =
    let* state = get c ~namespace in
    let updated_state = Model.increment state in
    let* () = upsert c updated_state in
    Lwt.return @@ Ok updated_state
end

module RepoMariaDb = struct
  let create_table_if_not_exists connection =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.exec Caqti_type.unit
        {sql|
CREATE TABLE IF NOT EXISTS core_migration_state (
  namespace VARCHAR(128) NOT NULL,
  version INTEGER,
  dirty BOOL NOT NULL,
  PRIMARY KEY (namespace)
);
 |sql}
    in
    Connection.exec request ()

  let get connection ~namespace =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.find_opt Caqti_type.string
        Caqti_type.(tup3 string int bool)
        {sql|
SELECT
  namespace,
  version,
  dirty
FROM core_migration_state
WHERE namespace = ?;
|sql}
    in
    let* result = Connection.find_opt request namespace in
    Lwt.return @@ Ok (result |> Option.map ~f:Model.of_tuple)

  let upsert connection ~state =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.exec
        Caqti_type.(tup3 string int bool)
        {sql|
INSERT INTO core_migration_state (
  namespace,
  version,
  dirty
) VALUES (
  ?,
  ?,
  ?
) ON DUPLICATE KEY UPDATE
version = VALUES(version),
dirty = VALUES(dirty)
|sql}
    in
    Connection.exec request (Model.to_tuple state)
end

module RepoPostgreSql = struct
  let create_table_if_not_exists connection =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.exec Caqti_type.unit
        {sql|
CREATE TABLE IF NOT EXISTS core_migration_state (
  namespace VARCHAR(128) NOT NULL PRIMARY KEY,
  version INTEGER,
  dirty BOOL NOT NULL
);
 |sql}
    in
    Connection.exec request ()

  let get connection ~namespace =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.find_opt Caqti_type.string
        Caqti_type.(tup3 string int bool)
        {sql|
SELECT
  namespace,
  version,
  dirty
FROM core_migration_state
WHERE namespace = ?;
|sql}
    in
    let* result = Connection.find_opt request namespace in
    Lwt.return @@ Ok (result |> Option.map ~f:Model.of_tuple)

  let upsert connection ~state =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.exec
        Caqti_type.(tup3 string int bool)
        {sql|
INSERT INTO core_migration_state (
  namespace,
  version,
  dirty
) VALUES (
  ?,
  ?,
  ?
) ON CONFLICT (namespace)
DO UPDATE SET version = EXCLUDED.version,
dirty = EXCLUDED.dirty
|sql}
    in
    Connection.exec request (Model.to_tuple state)
end

module PostgreSql = Make (RepoPostgreSql)
module MariaDb = Make (RepoMariaDb)

type step = string * string

type t = string * step list

let empty label = (label, [])

let create_step ~label query = (label, query)

let add_step step (label, steps) = (label, List.cons step steps)

let execute_steps migration conn =
  let (module Service : SERVICE) = Core.Registry.get key in
  let module Connection = (val conn : Caqti_lwt.CONNECTION) in
  let namespace, steps = migration in
  let open Lwt in
  let rec run steps conn =
    match steps with
    | [] -> Lwt_result.return ()
    | (name, query) :: steps -> (
        Logs.debug (fun m -> m "MIGRATION: Running %s" name);
        let req = Caqti_request.exec Caqti_type.unit query in
        Connection.exec req () >>= function
        | Ok () ->
            Logs.debug (fun m -> m "MIGRATION: Ran %s" name);
            let* _ = Service.increment conn ~namespace in
            run steps conn
        | Error err ->
            Logs.err (fun m ->
                m "MIGRATION: Error while running migration for %s %s" namespace
                  (Caqti_error.show err));
            failwith "Error while running migrations" )
  in
  let () =
    match List.length steps with
    | 0 ->
        Logs.debug (fun m ->
            m "MIGRATION: No migrations to apply for %s" namespace)
    | n ->
        Logs.debug (fun m ->
            m "MIGRATION: Applying %i migrations for %s" n namespace)
  in
  run steps conn

let execute_migration migration conn =
  let (module Service : SERVICE) = Core.Registry.get key in
  let namespace, _ = migration in
  Logs.debug (fun m -> m "MIGRATION: Execute migrations for app %s" namespace);
  let* () = Service.setup conn in
  let* has_state = Service.has conn ~namespace in
  let* state =
    if has_state then
      let* state = Service.get conn ~namespace in
      if Model.dirty state then (
        let msg =
          Printf.sprintf
            "Dirty migration found for app %s, has to be fixed manually"
            namespace
        in
        Logs.err (fun m -> m "MIGRATION: %s" msg);
        failwith msg )
      else Service.mark_dirty conn ~namespace
    else (
      Logs.debug (fun m -> m "MIGRATION: Setting up table for %s app" namespace);
      let state = Model.create ~namespace in
      let* () = Service.upsert conn state in
      Lwt.return @@ Ok state )
  in
  let migration_to_apply = Model.steps_to_apply migration state in
  let* () = execute_steps migration_to_apply conn in
  let* _ = Service.mark_clean conn ~namespace in
  Lwt.return @@ Ok ()

(* TODO We just need this because we leak caqti_errors everywhere. Once we hide
different caqti_errors, we can get rid of it and use ('a, string) Result.t everywhere *)
let to_caqti_error result =
  result
  |> Result.map_error ~f:(fun err ->
         Caqti_error.connect_failed ~uri:Uri.empty (Caqti_error.Msg err))

(* TODO gracefully try to disable and enable fk keys *)
let execute migrations =
  let open Lwt in
  let rec run migrations conn =
    match migrations with
    | [] -> Lwt_result.return ()
    | migration :: migrations -> (
        execute_migration migration conn >>= function
        | Ok () -> run migrations conn
        | Error err -> return (Error err) )
  in
  let pool = Core.Db.connect () in
  let result =
    Caqti_lwt.Pool.use (fun conn -> run migrations conn >|= to_caqti_error) pool
  in
  result |> Lwt_result.map_err Caqti_error.show
