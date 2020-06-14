open Base
module Model = Repo_migration_model

let ( let* ) = Lwt_result.bind

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
  Connection.exec request

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

let upsert connection state =
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
