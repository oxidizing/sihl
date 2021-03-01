module type Sig = sig
  val lifecycles : Sihl_core.Container.lifecycle list
  val insert : string -> unit Lwt.t
  val has : string -> bool Lwt.t
  val delete : string -> unit Lwt.t
  val register_cleaner : unit -> unit
  val register_migration : unit -> unit
end

module InMemory : Sig = struct
  let lifecycles = []
  let store = Hashtbl.create 100

  let insert token =
    Hashtbl.add store token ();
    Lwt.return ()
  ;;

  let has token = Lwt.return @@ Hashtbl.mem store token
  let delete token = Lwt.return @@ Hashtbl.remove store token

  let register_cleaner () =
    Sihl_core.Cleaner.register_cleaner (fun () ->
        Lwt.return (Hashtbl.clear store))
  ;;

  let register_migration () = ()
end

module MariaDb : Sig = struct
  module Migration = Sihl_persistence.Migration.MariaDb

  let lifecycles = [ Sihl_persistence.Database.lifecycle; Migration.lifecycle ]

  let insert_request =
    Caqti_request.exec
      Caqti_type.(tup2 string ptime)
      {sql|
        INSERT INTO token_blacklist (
          token_value,
          created_at
        ) VALUES (
          $1,
          $2
        )
        |sql}
  ;;

  let insert token =
    let now = Ptime_clock.now () in
    Sihl_persistence.Database.query
      (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec insert_request (token, now)
        |> Lwt.map Sihl_persistence.Database.raise_error)
  ;;

  let find_request_opt =
    Caqti_request.find_opt
      Caqti_type.string
      Caqti_type.(tup2 string ptime)
      {sql|
        SELECT
          token_value,
          created_at
        FROM token_blacklist
        WHERE token_blacklist.token_value = ?
        |sql}
  ;;

  let find_opt token =
    Sihl_persistence.Database.query
      (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.find_opt find_request_opt token
        |> Lwt.map Sihl_persistence.Database.raise_error)
  ;;

  let has token =
    let open Lwt.Syntax in
    let* token = find_opt token in
    Lwt.return @@ Option.is_some token
  ;;

  let delete_request =
    Caqti_request.exec
      Caqti_type.string
      {sql|
        DELETE FROM token_blacklist
        WHERE token_blacklist.token_value = ?
        |sql}
  ;;

  let delete token =
    Sihl_persistence.Database.query
      (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec delete_request token
        |> Lwt.map Sihl_persistence.Database.raise_error)
  ;;

  let fix_collation =
    Sihl_persistence.Migration.create_step
      ~label:"fix collation"
      "SET collation_server = 'utf8mb4_unicode_ci';"
  ;;

  let create_jobs_table =
    Sihl_persistence.Migration.create_step
      ~label:"create token blacklist table"
      {sql|
CREATE TABLE IF NOT EXISTS token_blacklist (
  id BIGINT UNSIGNED AUTO_INCREMENT,
  token_value VARCHAR(2000) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
|sql}
  ;;

  let migration =
    Sihl_persistence.Migration.(
      empty "tokens_blacklist"
      |> add_step fix_collation
      |> add_step create_jobs_table)
  ;;

  let register_migration () = Migration.register_migration migration

  let clean_request =
    Caqti_request.exec Caqti_type.unit "TRUNCATE token_blacklist;"
  ;;

  let clean () =
    Sihl_persistence.Database.query
      (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec clean_request ()
        |> Lwt.map Sihl_persistence.Database.raise_error)
  ;;

  let register_cleaner () = Sihl_core.Cleaner.register_cleaner clean
end

module PostgreSql : Sig = struct
  module Migration = Sihl_persistence.Migration.PostgreSql

  let lifecycles = [ Sihl_persistence.Database.lifecycle; Migration.lifecycle ]

  let insert_request =
    Caqti_request.exec
      Caqti_type.(tup2 string ptime)
      {sql|
        INSERT INTO token_blacklist (
          token_value,
          created_at
        ) VALUES (
          $1,
          $2
        )
        |sql}
  ;;

  let insert token =
    let now = Ptime_clock.now () in
    Sihl_persistence.Database.query
      (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec insert_request (token, now)
        |> Lwt.map Sihl_persistence.Database.raise_error)
  ;;

  let find_request_opt =
    Caqti_request.find_opt
      Caqti_type.string
      Caqti_type.(tup2 string ptime)
      {sql|
       SELECT
          token_value,
          created_at
        FROM token_blacklist
        WHERE token_blacklist.token_value = ?
        |sql}
  ;;

  let find_opt token =
    Sihl_persistence.Database.query
      (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.find_opt find_request_opt token
        |> Lwt.map Sihl_persistence.Database.raise_error)
  ;;

  let has token =
    let open Lwt.Syntax in
    let* token = find_opt token in
    Lwt.return @@ Option.is_some token
  ;;

  let delete_request =
    Caqti_request.exec
      Caqti_type.string
      {sql|
        DELETE FROM token_blacklist
        WHERE token_blacklist.token_value = ?
        |sql}
  ;;

  let delete token =
    Sihl_persistence.Database.query
      (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec delete_request token
        |> Lwt.map Sihl_persistence.Database.raise_error)
  ;;

  let create_jobs_table =
    Sihl_persistence.Migration.create_step
      ~label:"create token blacklist table"
      {sql|
CREATE TABLE IF NOT EXISTS token_blacklist (
  id serial,
  token_value VARCHAR(2000) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
);
|sql}
  ;;

  let migration =
    Sihl_persistence.Migration.(
      empty "tokens_blacklist" |> add_step create_jobs_table)
  ;;

  let register_migration () = Migration.register_migration migration

  let clean_request =
    Caqti_request.exec Caqti_type.unit "TRUNCATE token_blacklist;"
  ;;

  let clean () =
    Sihl_persistence.Database.query
      (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec clean_request ()
        |> Lwt.map Sihl_persistence.Database.raise_error)
  ;;

  let register_cleaner () = Sihl_core.Cleaner.register_cleaner clean
end
