module type Sig = sig
  val lifecycles : Sihl.Container.lifecycle list
  val register_migration : unit -> unit
  val register_cleaner : unit -> unit
  val find : string -> string option Lwt.t
  val insert : string * string -> unit Lwt.t
  val update : string * string -> unit Lwt.t
  val delete : string -> unit Lwt.t
end

(* Common functions that are shared by SQL implementations *)

let find_request =
  Caqti_request.find_opt
    Caqti_type.string
    Caqti_type.string
    {sql|
        SELECT
          cache_value
        FROM cache
        WHERE cache.cache_key = ?
        |sql}
;;

let find key =
  Sihl.Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
      Connection.find_opt find_request key |> Lwt.map Sihl.Database.raise_error)
;;

let insert_request =
  Caqti_request.exec
    Caqti_type.(tup2 string string)
    {sql|
        INSERT INTO cache (
          cache_key,
          cache_value
        ) VALUES (
          ?,
          ?
        )
        |sql}
;;

let insert key_value =
  Sihl.Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
      Connection.exec insert_request key_value
      |> Lwt.map Sihl.Database.raise_error)
;;

let update_request =
  Caqti_request.exec
    Caqti_type.(tup2 string string)
    {sql|
        UPDATE cache SET
          cache_value = $2
        WHERE cache_key = $1
        |sql}
;;

let update key_value =
  Sihl.Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
      Connection.exec update_request key_value
      |> Lwt.map Sihl.Database.raise_error)
;;

let delete_request =
  Caqti_request.exec
    Caqti_type.string
    {sql|
      DELETE FROM cache 
      WHERE cache.cache_key = ?
      |sql}
;;

let delete key =
  Sihl.Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
      Connection.exec delete_request key |> Lwt.map Sihl.Database.raise_error)
;;

let clean_request = Caqti_request.exec Caqti_type.unit "TRUNCATE TABLE cache;"

let clean () =
  Sihl.Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
      Connection.exec clean_request () |> Lwt.map Sihl.Database.raise_error)
;;

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
         ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
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
         );
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
