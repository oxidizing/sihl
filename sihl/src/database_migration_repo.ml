module Migration = struct
  type t =
    { namespace : string
    ; version : int
    ; dirty : bool
    }
  [@@deriving fields]

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

  val create_table_if_not_exists : string -> unit Lwt.t
  val get : string -> namespace:string -> Migration.t option Lwt.t
  val get_all : string -> Migration.t list Lwt.t
  val upsert : string -> Migration.t -> unit Lwt.t
end

(* Common functions *)
let get_request table =
  Caqti_request.find_opt
    Caqti_type.string
    Caqti_type.(tup3 string int bool)
    (Format.sprintf
       {sql|
       SELECT
         namespace,
         version,
         dirty
       FROM %s
       WHERE namespace = ?;
       |sql}
       table)
;;

let get table ~namespace =
  Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
      Connection.find_opt (get_request table) namespace
      |> Lwt.map Database.raise_error)
  |> Lwt.map (Option.map Migration.of_tuple)
;;

let get_all_request table =
  Caqti_request.collect
    Caqti_type.unit
    Caqti_type.(tup3 string int bool)
    (Format.sprintf
       {sql|
       SELECT
         namespace,
         version,
         dirty
       FROM %s;
       |sql}
       table)
;;

let get_all table =
  Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
      Connection.collect_list (get_all_request table) ()
      |> Lwt.map Database.raise_error)
  |> Lwt.map (List.map Migration.of_tuple)
;;

module MariaDb : Sig = struct
  module Migration = Migration

  let create_request table =
    Caqti_request.exec
      Caqti_type.unit
      (Format.sprintf
         {sql|
       CREATE TABLE IF NOT EXISTS %s (
         namespace VARCHAR(128) NOT NULL,
         version INTEGER,
         dirty BOOL NOT NULL,
       PRIMARY KEY (namespace)
       ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
      |sql}
         table)
  ;;

  let create_table_if_not_exists table =
    Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec (create_request table) ()
        |> Lwt.map Database.raise_error)
  ;;

  let get = get
  let get_all = get_all

  let upsert_request table =
    Caqti_request.exec
      Caqti_type.(tup3 string int bool)
      (Format.sprintf
         {sql|
       INSERT INTO %s (
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
         table)
  ;;

  let upsert table state =
    Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec (upsert_request table) (Migration.to_tuple state)
        |> Lwt.map Database.raise_error)
  ;;
end

module PostgreSql : Sig = struct
  module Migration = Migration

  let create_request table =
    Caqti_request.exec
      Caqti_type.unit
      (Format.sprintf
         {sql|
       CREATE TABLE IF NOT EXISTS %s (
         namespace VARCHAR(128) NOT NULL PRIMARY KEY,
         version INTEGER,
         dirty BOOL NOT NULL
       );
       |sql}
         table)
  ;;

  let create_table_if_not_exists table =
    Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec (create_request table) ()
        |> Lwt.map Database.raise_error)
  ;;

  let get = get
  let get_all = get_all

  let upsert_request table =
    Caqti_request.exec
      Caqti_type.(tup3 string int bool)
      (Format.sprintf
         {sql|
       INSERT INTO %s (
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
         table)
  ;;

  let upsert table state =
    Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec (upsert_request table) (Migration.to_tuple state)
        |> Lwt.map Database.raise_error)
  ;;
end
