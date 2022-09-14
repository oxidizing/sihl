module type Sig = sig
  val lifecycles : Sihl.Container.lifecycle list
  val insert : ?ctx:(string * string) list -> string -> unit Lwt.t
  val has : ?ctx:(string * string) list -> string -> bool Lwt.t
  val delete : ?ctx:(string * string) list -> string -> unit Lwt.t
  val register_cleaner : unit -> unit
  val register_migration : unit -> unit
end

module InMemory : Sig = struct
  let lifecycles = []
  let store = Hashtbl.create 100

  let insert ?ctx:_ token =
    Hashtbl.add store token ();
    Lwt.return ()
  ;;

  let has ?ctx:_ token = Lwt.return @@ Hashtbl.mem store token
  let delete ?ctx:_ token = Lwt.return @@ Hashtbl.remove store token

  let register_cleaner () =
    Sihl.Cleaner.register_cleaner (fun ?ctx:_ () ->
      Lwt.return (Hashtbl.clear store))
  ;;

  let register_migration () = ()
end

module MariaDb : Sig = struct
  module Migration = Sihl.Database.Migration.MariaDb

  let lifecycles = [ Sihl.Database.lifecycle; Migration.lifecycle ]

  let insert_request =
    let open Caqti_request.Infix in
    {sql|
      INSERT INTO token_blacklist (
        token_value,
        created_at
      ) VALUES (
        $1,
        $2
      )
    |sql}
    |> Caqti_type.(tup2 string ptime ->. unit)
  ;;

  let insert ?ctx token =
    let now = Ptime_clock.now () in
    Sihl.Database.exec ?ctx insert_request (token, now)
  ;;

  let find_request_opt =
    let open Caqti_request.Infix in
    {sql|
      SELECT
        token_value,
        created_at
      FROM token_blacklist
      WHERE token_blacklist.token_value = ?
    |sql}
    |> Caqti_type.(string ->? tup2 string ptime)
  ;;

  let find_opt ?ctx token = Sihl.Database.find_opt ?ctx find_request_opt token

  let has ?ctx token =
    let%lwt token = find_opt ?ctx token in
    Lwt.return @@ Option.is_some token
  ;;

  let delete_request =
    let open Caqti_request.Infix in
    {sql|
      DELETE FROM token_blacklist
      WHERE token_blacklist.token_value = ?
    |sql}
    |> Caqti_type.(string ->. unit)
  ;;

  let delete ?ctx token = Sihl.Database.exec ?ctx delete_request token

  let fix_collation =
    Sihl.Database.Migration.create_step
      ~label:"fix collation"
      "SET collation_server = 'utf8mb4_unicode_ci'"
  ;;

  let create_jobs_table =
    Sihl.Database.Migration.create_step
      ~label:"create token blacklist table"
      {sql|
        CREATE TABLE IF NOT EXISTS token_blacklist (
          id BIGINT UNSIGNED AUTO_INCREMENT,
          token_value VARCHAR(2000) NOT NULL,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      |sql}
  ;;

  let migration =
    Sihl.Database.Migration.(
      empty "tokens_blacklist"
      |> add_step fix_collation
      |> add_step create_jobs_table)
  ;;

  let register_migration () = Migration.register_migration migration

  let clean_request =
    let open Caqti_request.Infix in
    "TRUNCATE token_blacklist" |> Caqti_type.(unit ->. unit)
  ;;

  let clean ?ctx () = Sihl.Database.exec ?ctx clean_request ()
  let register_cleaner () = Sihl.Cleaner.register_cleaner clean
end

module PostgreSql : Sig = struct
  module Migration = Sihl.Database.Migration.PostgreSql

  let lifecycles = [ Sihl.Database.lifecycle; Migration.lifecycle ]

  let insert_request =
    let open Caqti_request.Infix in
    {sql|
      INSERT INTO token_blacklist (
        token_value,
        created_at
      ) VALUES (
        $1,
        $2 AT TIME ZONE 'UTC'
      )
    |sql}
    |> Caqti_type.(tup2 string ptime ->. unit)
  ;;

  let insert ?ctx token =
    let now = Ptime_clock.now () in
    Sihl.Database.exec ?ctx insert_request (token, now)
  ;;

  let find_request_opt =
    let open Caqti_request.Infix in
    {sql|
      SELECT
        token_value,
        created_at
      FROM token_blacklist
      WHERE token_blacklist.token_value = ?
    |sql}
    |> Caqti_type.(string ->? tup2 string ptime)
  ;;

  let find_opt ?ctx token = Sihl.Database.find_opt ?ctx find_request_opt token

  let has ?ctx token =
    let%lwt token = find_opt ?ctx token in
    Lwt.return @@ Option.is_some token
  ;;

  let delete_request =
    let open Caqti_request.Infix in
    {sql|
      DELETE FROM token_blacklist
      WHERE token_blacklist.token_value = ?
    |sql}
    |> Caqti_type.(string ->. unit)
  ;;

  let delete ?ctx token = Sihl.Database.exec ?ctx delete_request token

  let create_jobs_table =
    Sihl.Database.Migration.create_step
      ~label:"create token blacklist table"
      {sql|
        CREATE TABLE IF NOT EXISTS token_blacklist (
          id serial,
          token_value VARCHAR(2000) NOT NULL,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (id)
        )
      |sql}
  ;;

  let remove_timezone =
    Sihl.Database.Migration.create_step
      ~label:"remove timezone info from timestamps"
      {sql|
        ALTER TABLE token_blacklist
          ALTER COLUMN created_at TYPE TIMESTAMP
      |sql}
  ;;

  let migration =
    Sihl.Database.Migration.(
      empty "tokens_blacklist"
      |> add_step create_jobs_table
      |> add_step remove_timezone)
  ;;

  let register_migration () = Migration.register_migration migration

  let clean_request =
    let open Caqti_request.Infix in
    "TRUNCATE token_blacklist" |> Caqti_type.(unit ->. unit)
  ;;

  let clean ?ctx () = Sihl.Database.exec ?ctx clean_request ()
  let register_cleaner () = Sihl.Cleaner.register_cleaner clean
end
