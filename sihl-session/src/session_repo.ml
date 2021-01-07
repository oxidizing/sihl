open Lwt.Syntax
module Database = Sihl_persistence.Database
module Cleaner = Sihl_core.Cleaner
module Migration = Sihl_facade.Migration

module type Sig = sig
  val lifecycles : Sihl_core.Container.Lifecycle.t list
  val register_migration : unit -> unit
  val register_cleaner : unit -> unit
  val find_all : unit -> Sihl_contract.Session.t list Lwt.t
  val find_opt : string -> Sihl_contract.Session.t option Lwt.t

  val find_data
    :  Sihl_contract.Session.t
    -> string Sihl_contract.Session.Map.t Lwt.t

  val insert
    :  Sihl_contract.Session.t
    -> string Sihl_contract.Session.Map.t
    -> unit Lwt.t

  val update
    :  Sihl_contract.Session.t
    -> string Sihl_contract.Session.Map.t
    -> unit Lwt.t

  val delete : string -> unit Lwt.t
end

type k_v = (string * string) list [@@deriving yojson]

(* Encoding & decoding of sessions *)

let string_of_data data =
  data
  |> Sihl_contract.Session.Map.to_seq
  |> List.of_seq
  |> k_v_to_yojson
  |> Yojson.Safe.to_string
;;

let data_of_string str =
  str
  |> Yojson.Safe.from_string
  |> k_v_of_yojson
  |> Result.map List.to_seq
  |> Result.map Sihl_contract.Session.Map.of_seq
;;

let t =
  let open Sihl_contract.Session in
  let encode m = Ok (m.key, m.expire_date) in
  let decode (key, expire_date) = Ok { key; expire_date } in
  Caqti_type.(custom ~encode ~decode (tup2 string ptime))
;;

module MakeMariaDb (MigrationService : Sihl_contract.Migration.Sig) : Sig =
struct
  let lifecycles =
    [ Database.lifecycle; Cleaner.lifecycle; MigrationService.lifecycle ]
  ;;

  let find_all_request =
    Caqti_request.find
      Caqti_type.unit
      t
      {sql|
        SELECT
          session_key,
          expire_date
        FROM session_sessions
        |sql}
  ;;

  let find_all () =
    Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.collect_list find_all_request ()
        |> Lwt.map Database.raise_error)
  ;;

  let find_opt_request =
    Caqti_request.find_opt
      Caqti_type.string
      t
      {sql|
        SELECT
          session_key,
          expire_date
        FROM session_sessions
        WHERE session_sessions.session_key = ?
        |sql}
  ;;

  let find_opt key =
    Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.find_opt find_opt_request key |> Lwt.map Database.raise_error)
  ;;

  let find_data_request =
    Caqti_request.find
      Caqti_type.string
      Caqti_type.string
      {sql|
        SELECT
          session_data
        FROM session_sessions
        WHERE session_sessions.session_key = ?
        |sql}
  ;;

  let find_data session =
    let key = Sihl_facade.Session.key session in
    let* data =
      Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.find find_data_request key |> Lwt.map Database.raise_error)
    in
    match data_of_string data with
    | Ok data -> Lwt.return data
    | Error msg -> raise @@ Sihl_contract.Session.Exception msg
  ;;

  let insert_request =
    Caqti_request.exec
      Caqti_type.(tup3 string string ptime)
      {sql|
        INSERT INTO session_sessions (
          session_key,
          session_data,
          expire_date
        ) VALUES (
          ?,
          ?,
          ?
        )
        |sql}
  ;;

  let insert session data_map =
    let open Sihl_contract.Session in
    let data = string_of_data data_map in
    let input = session.key, data, session.expire_date in
    Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec insert_request input |> Lwt.map Database.raise_error)
  ;;

  let update_request =
    Caqti_request.exec
      Caqti_type.(tup3 string string ptime)
      {sql|
        UPDATE session_sessions SET
          session_data = $2,
          expire_date = $3
        WHERE session_key = $1
        |sql}
  ;;

  let update session data_map =
    let open Sihl_contract.Session in
    let data = string_of_data data_map in
    let input = session.key, data, session.expire_date in
    Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec update_request input |> Lwt.map Database.raise_error)
  ;;

  let delete_request =
    Caqti_request.exec
      Caqti_type.string
      {sql|
      DELETE FROM session_sessions
      WHERE session_sessions.session_key = ?
      |sql}
  ;;

  let delete key =
    Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec delete_request key |> Lwt.map Database.raise_error)
  ;;

  let clean_request =
    Caqti_request.exec
      Caqti_type.unit
      {sql|
           TRUNCATE session_sessions;
          |sql}
  ;;

  let clean () =
    Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec clean_request () |> Lwt.map Database.raise_error)
  ;;

  module Migration = struct
    let create_sessions_table =
      Migration.create_step
        ~label:"create sessions table"
        {sql|
CREATE TABLE IF NOT EXISTS session_sessions (
  id serial,
  session_key VARCHAR(64) NOT NULL,
  session_data VARCHAR(1024) NOT NULL,
  expire_date TIMESTAMP NOT NULL,
  PRIMARY KEY(id),
  CONSTRAINT unique_key UNIQUE(session_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
|sql}
    ;;

    let migration () =
      Migration.(empty "session" |> add_step create_sessions_table)
    ;;
  end

  let register_migration () =
    MigrationService.register_migration (Migration.migration ())
  ;;

  let register_cleaner () = Cleaner.register_cleaner clean
end

module MakePostgreSql (MigrationService : Sihl_contract.Migration.Sig) : Sig =
struct
  let lifecycles =
    [ Database.lifecycle; Cleaner.lifecycle; MigrationService.lifecycle ]
  ;;

  let find_all_request =
    Caqti_request.collect
      Caqti_type.unit
      t
      {sql|
        SELECT
          session_key,
          expire_date
        FROM session_sessions
        |sql}
  ;;

  let find_all () =
    Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.collect_list find_all_request ()
        |> Lwt.map Database.raise_error)
  ;;

  let find_opt_request =
    Caqti_request.find_opt
      Caqti_type.string
      t
      {sql|
        SELECT
          session_key,
          expire_date
        FROM session_sessions
        WHERE session_sessions.session_key = ?
        |sql}
  ;;

  let find_opt key =
    Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.find_opt find_opt_request key |> Lwt.map Database.raise_error)
  ;;

  let find_data_request =
    Caqti_request.find
      Caqti_type.string
      Caqti_type.string
      {sql|
        SELECT
          session_data
        FROM session_sessions
        WHERE session_sessions.session_key = ?
        |sql}
  ;;

  let find_data session =
    let key = Sihl_facade.Session.key session in
    let* data =
      Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.find find_data_request key |> Lwt.map Database.raise_error)
    in
    match data_of_string data with
    | Ok data -> Lwt.return data
    | Error msg -> raise @@ Sihl_contract.Session.Exception msg
  ;;

  let insert_request =
    Caqti_request.exec
      Caqti_type.(tup3 string string ptime)
      {sql|
        INSERT INTO session_sessions (
          session_key,
          session_data,
          expire_date
        ) VALUES (
          ?,
          ?,
          ?
        )
        |sql}
  ;;

  let insert session data_map =
    let open Sihl_contract.Session in
    let data = string_of_data data_map in
    let input = session.key, data, session.expire_date in
    Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec insert_request input |> Lwt.map Database.raise_error)
  ;;

  let update_request =
    Caqti_request.exec
      Caqti_type.(tup3 string string ptime)
      {sql|
        UPDATE session_sessions SET
          session_data = $2,
          expire_date = $3
        WHERE session_key = $1
        |sql}
  ;;

  let update session data_map =
    let open Sihl_contract.Session in
    let data = string_of_data data_map in
    let input = session.key, data, session.expire_date in
    Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec update_request input |> Lwt.map Database.raise_error)
  ;;

  let delete_request =
    Caqti_request.exec
      Caqti_type.string
      {sql|
      DELETE FROM session_sessions
      WHERE session_sessions.session_key = ?
           |sql}
  ;;

  let delete key =
    Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec delete_request key |> Lwt.map Database.raise_error)
  ;;

  let clean_request =
    Caqti_request.exec
      Caqti_type.unit
      {sql|
        TRUNCATE TABLE session_sessions CASCADE;
        |sql}
  ;;

  let clean () =
    Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
        Connection.exec clean_request () |> Lwt.map Database.raise_error)
  ;;

  module Migration = struct
    let create_sessions_table =
      Migration.create_step
        ~label:"create sessions table"
        {sql|
CREATE TABLE IF NOT EXISTS session_sessions (
  id serial,
  session_key VARCHAR NOT NULL,
  session_data TEXT NOT NULL,
  expire_date TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE (session_key)
);
|sql}
    ;;

    let migration () =
      Migration.(empty "session" |> add_step create_sessions_table)
    ;;
  end

  let register_migration () =
    MigrationService.register_migration (Migration.migration ())
  ;;

  let register_cleaner () = Cleaner.register_cleaner clean
end
