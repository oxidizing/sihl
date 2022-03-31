module type Sig = sig
  val lifecycles : Sihl.Container.lifecycle list
  val register_migration : unit -> unit
  val register_cleaner : unit -> unit
  val find : ?ctx:(string * string) list -> string -> string option Lwt.t
  val insert : ?ctx:(string * string) list -> string * string -> unit Lwt.t
  val update : ?ctx:(string * string) list -> string * string -> unit Lwt.t
  val delete : ?ctx:(string * string) list -> string -> unit Lwt.t
end

(* Common functions that are shared by SQL implementations *)

let find_request =
  let open Caqti_request.Infix in
  {sql|
    SELECT
      cache_value
    FROM cache
    WHERE cache.cache_key = ?
  |sql}
  |> Caqti_type.(string ->? string)
;;

let find ?ctx key = Sihl.Database.find_opt ?ctx find_request key

let insert_request =
  let open Caqti_request.Infix in
  {sql|
    INSERT INTO cache (
      cache_key,
      cache_value
    ) VALUES (
      ?,
      ?
    )
  |sql}
  |> Caqti_type.(tup2 string string ->. unit)
;;

let insert ?ctx key_value = Sihl.Database.exec ?ctx insert_request key_value

let update_request =
  let open Caqti_request.Infix in
  {sql|
    UPDATE cache SET
      cache_value = $2
    WHERE cache_key = $1
  |sql}
  |> Caqti_type.(tup2 string string ->. unit)
;;

let update ?ctx key_value = Sihl.Database.exec ?ctx update_request key_value

let delete_request =
  let open Caqti_request.Infix in
  {sql|
    DELETE FROM cache
    WHERE cache.cache_key = ?
  |sql}
  |> Caqti_type.(string ->. unit)
;;

let delete ?ctx key = Sihl.Database.exec ?ctx delete_request key

let clean_request =
  let open Caqti_request.Infix in
  "TRUNCATE TABLE cache" |> Caqti_type.(unit ->. unit)
;;

let clean ?ctx () = Sihl.Database.exec clean_request ?ctx ()

module MakeMariaDb (MigrationService : Sihl.Contract.Migration.Sig) : Sig =
struct
  let lifecycles = [ Sihl.Database.lifecycle; MigrationService.lifecycle ]
  let find = find
  let insert = insert
  let update = update
  let delete = delete
  let clean = clean

  module Migration = struct
    let create_cache_table =
      Sihl.Database.Migration.create_step
        ~label:"create cache table"
        {sql|
          CREATE TABLE IF NOT EXISTS cache (
            id serial,
            cache_key VARCHAR(64) NOT NULL,
            cache_value VARCHAR(1024) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY(id),
            CONSTRAINT unique_key UNIQUE(cache_key)
          ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        |sql}
    ;;

    let migration () =
      Sihl.Database.Migration.(empty "cache" |> add_step create_cache_table)
    ;;
  end

  let register_migration () =
    MigrationService.register_migration (Migration.migration ())
  ;;

  let register_cleaner () = Sihl.Cleaner.register_cleaner clean
end

module MakePostgreSql (MigrationService : Sihl.Contract.Migration.Sig) : Sig =
struct
  let lifecycles = [ Sihl.Database.lifecycle; MigrationService.lifecycle ]
  let find = find
  let insert = insert
  let update = update
  let delete = delete
  let clean = clean

  module Migration = struct
    let create_cache_table =
      Sihl.Database.Migration.create_step
        ~label:"create cache table"
        {sql|
          CREATE TABLE IF NOT EXISTS cache (
            id serial,
            cache_key VARCHAR NOT NULL,
            cache_value TEXT NOT NULL,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE (cache_key)
          )
        |sql}
    ;;

    let remove_timezone =
      Sihl.Database.Migration.create_step
        ~label:"remove timezone info from timestamps"
        {sql|
          ALTER TABLE cache
            ALTER COLUMN created_at TYPE TIMESTAMP
        |sql}
    ;;

    let migration () =
      Sihl.Database.Migration.(
        empty "cache" |> add_step create_cache_table |> add_step remove_timezone)
    ;;
  end

  let register_migration () =
    MigrationService.register_migration (Migration.migration ())
  ;;

  let register_cleaner () = Sihl.Cleaner.register_cleaner clean
end
