module Migration = struct
  type t =
    { namespace : string
    ; version : int
    ; dirty : bool
    }
  [@@deriving fields, eq, show]

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

  val create_table_if_not_exists
    :  ?ctx:(string * string) list
    -> string
    -> unit Lwt.t

  val get
    :  ?ctx:(string * string) list
    -> string
    -> namespace:string
    -> Migration.t option Lwt.t

  val get_all : ?ctx:(string * string) list -> string -> Migration.t list Lwt.t

  val upsert
    :  ?ctx:(string * string) list
    -> string
    -> Migration.t
    -> unit Lwt.t
end

(* Common functions *)
let get_request table =
  let open Caqti_request.Infix in
  Format.sprintf
    {sql|
       SELECT
         namespace,
         version,
         dirty
       FROM %s
       WHERE namespace = ?
    |sql}
    table
  |> Caqti_type.(string ->? tup3 string int bool)
;;

let get ?ctx table ~namespace =
  Database.find_opt ?ctx (get_request table) namespace
  |> Lwt.map (Option.map Migration.of_tuple)
;;

let get_all_request table =
  let open Caqti_request.Infix in
  Format.sprintf
    {sql|
       SELECT
         namespace,
         version,
         dirty
       FROM %s
    |sql}
    table
  |> Caqti_type.(unit ->* tup3 string int bool)
;;

let get_all ?ctx table =
  Database.collect ?ctx (get_all_request table) ()
  |> Lwt.map (List.map Migration.of_tuple)
;;

module MariaDb : Sig = struct
  module Migration = Migration

  let create_request table =
    let open Caqti_request.Infix in
    Format.sprintf
      {sql|
        CREATE TABLE IF NOT EXISTS %s (
          namespace VARCHAR(128) NOT NULL,
          version INTEGER,
          dirty BOOL NOT NULL,
        PRIMARY KEY (namespace)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      |sql}
      table
    |> Caqti_type.(unit ->. unit)
  ;;

  let create_table_if_not_exists ?ctx table =
    Database.exec ?ctx (create_request table) ()
  ;;

  let get = get
  let get_all = get_all

  let upsert_request table =
    let open Caqti_request.Infix in
    Format.sprintf
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
      table
    |> Caqti_type.(tup3 string int bool ->. unit)
  ;;

  let upsert ?ctx table state =
    Database.exec ?ctx (upsert_request table) (Migration.to_tuple state)
  ;;
end

module PostgreSql : Sig = struct
  module Migration = Migration

  let create_request table =
    let open Caqti_request.Infix in
    Format.sprintf
      {sql|
        CREATE TABLE IF NOT EXISTS %s (
          namespace VARCHAR(128) NOT NULL PRIMARY KEY,
          version INTEGER,
          dirty BOOL NOT NULL
        )
      |sql}
      table
    |> Caqti_type.(unit ->. unit)
  ;;

  let create_table_if_not_exists ?ctx table =
    Database.exec ?ctx (create_request table) ()
  ;;

  let get = get
  let get_all = get_all

  let upsert_request table =
    let open Caqti_request.Infix in
    Format.sprintf
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
      table
    |> Caqti_type.(tup3 string int bool ->. unit)
  ;;

  let upsert ?ctx table state =
    Database.exec ?ctx (upsert_request table) (Migration.to_tuple state)
  ;;
end
