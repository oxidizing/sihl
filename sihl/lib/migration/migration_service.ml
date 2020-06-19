open Base
open Migration_sig
module Model = Migration_model

let ( let* ) = Lwt_result.bind

let key : (module SERVICE) Core_container.Key.t =
  Core_container.Key.create "migration.service"

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

  let provide_repo = None
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

let postgresql = Core.Container.bind key (module PostgreSql)

module MariaDb = Make (RepoMariaDb)

let mariadb =
  Core.Container.create_binding key (module MariaDb) MariaDb.provide_repo
