module Database = Sihl_database

module MariaDb : Sig.REPO = struct
  let create_request =
    Caqti_request.exec
      Caqti_type.unit
      {sql|
CREATE TABLE IF NOT EXISTS core_migration_state (
  namespace VARCHAR(128) NOT NULL,
  version INTEGER,
  dirty BOOL NOT NULL,
  PRIMARY KEY (namespace)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
 |sql}
  ;;

  let create_table_if_not_exists ctx =
    Database.Service.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec create_request () |> Lwt.map Result.get_ok)
  ;;

  let get_request =
    Caqti_request.find_opt
      Caqti_type.string
      Caqti_type.(tup3 string int bool)
      {sql|
SELECT
  namespace,
  version,
  dirty
FROM core_migration_state
WHERE namespace = ?;
|sql}
  ;;

  let get ctx ~namespace =
    Database.Service.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.find_opt get_request namespace |> Lwt.map Result.get_ok)
    |> Lwt.map (Option.map Model.of_tuple)
  ;;

  let upsert_request =
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
  ;;

  let upsert ctx ~state =
    Database.Service.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec upsert_request (Model.to_tuple state) |> Lwt.map Result.get_ok)
  ;;
end

module MakePostgreSql (Database : Database.Sig.SERVICE) : Sig.REPO = struct
  module Database = Database

  let create_request =
    Caqti_request.exec
      Caqti_type.unit
      {sql|
CREATE TABLE IF NOT EXISTS core_migration_state (
  namespace VARCHAR(128) NOT NULL PRIMARY KEY,
  version INTEGER,
  dirty BOOL NOT NULL
);
 |sql}
  ;;

  let create_table_if_not_exists ctx =
    Database.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec create_request () |> Lwt.map Result.get_ok)
  ;;

  let get_request =
    Caqti_request.find_opt
      Caqti_type.string
      Caqti_type.(tup3 string int bool)
      {sql|
SELECT
  namespace,
  version,
  dirty
FROM core_migration_state
WHERE namespace = ?;
|sql}
  ;;

  let get ctx ~namespace =
    Database.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.find_opt get_request namespace |> Lwt.map Result.get_ok)
    |> Lwt.map (Option.map Model.of_tuple)
  ;;

  let upsert_request =
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
  ;;

  let upsert ctx ~state =
    Database.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec upsert_request (Model.to_tuple state) |> Lwt.map Result.get_ok)
  ;;
end
