module Migration = struct
  type t =
    { namespace : string
    ; version : int
    ; dirty : bool
    }

  let create ~namespace = { namespace; version = 0; dirty = true }
  let mark_dirty state = { state with dirty = true }
  let mark_clean state = { state with dirty = false }
  let increment state = { state with version = state.version + 1 }

  let steps_to_apply (namespace, steps) { version; _ } =
    namespace, CCList.drop version steps
  ;;

  let of_tuple (namespace, version, dirty) = { namespace; version; dirty }
  let to_tuple state = state.namespace, state.version, state.dirty
  let dirty state = state.dirty
end

module type Sig = sig
  module Migration = Migration

  val create_table_if_not_exists : unit -> unit Lwt.t
  val get : namespace:string -> Migration.t option Lwt.t
  val upsert : state:Migration.t -> unit Lwt.t
end

module MariaDb : Sig = struct
  module Migration = Migration

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

  let create_table_if_not_exists () =
    Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec create_request () |> Lwt.map Database.raise_error)
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

  let get ~namespace =
    Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.find_opt get_request namespace
        |> Lwt.map Database.raise_error)
    |> Lwt.map (Option.map Migration.of_tuple)
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

  let upsert ~state =
    Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec upsert_request (Migration.to_tuple state)
        |> Lwt.map Database.raise_error)
  ;;
end

module PostgreSql : Sig = struct
  module Migration = Migration

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

  let create_table_if_not_exists () =
    Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec create_request () |> Lwt.map Database.raise_error)
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

  let get ~namespace =
    Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.find_opt get_request namespace
        |> Lwt.map Database.raise_error)
    |> Lwt.map (Option.map Migration.of_tuple)
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

  let upsert ~state =
    Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec upsert_request (Migration.to_tuple state)
        |> Lwt.map Database.raise_error)
  ;;
end
