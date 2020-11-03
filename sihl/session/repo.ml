module Database = Sihl_database
module Migration = Sihl_migration
module Repository = Sihl_repository

module MakeMariaDb (MigrationService : Migration.Sig.SERVICE) : Sig.REPO = struct
  module Sql = struct
    module Model = Model

    let find_all_request =
      Caqti_request.find
        Caqti_type.unit
        Model.t
        {sql|
        SELECT
          session_key,
          session_data,
          expire_date
        FROM session_sessions
        |sql}
    ;;

    let find_all ctx =
      Database.Service.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.collect_list find_all_request () |> Lwt.map Result.get_ok)
    ;;

    let find_opt_request =
      Caqti_request.find_opt
        Caqti_type.string
        Model.t
        {sql|
        SELECT
          session_key,
          session_data,
          expire_date
        FROM session_sessions
        WHERE session_sessions.session_key = ?
        |sql}
    ;;

    let find_opt ctx ~key =
      Database.Service.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.find_opt find_opt_request key |> Lwt.map Result.get_ok)
    ;;

    let insert_request =
      Caqti_request.exec
        Model.t
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

    let insert ctx session =
      Database.Service.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec insert_request session |> Lwt.map Result.get_ok)
    ;;

    let update_request =
      Caqti_request.exec
        Model.t
        {sql|
        UPDATE session_sessions SET
          session_data = $2,
          expire_date = $3
        WHERE session_key = $1
        |sql}
    ;;

    let update ctx session =
      Database.Service.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec update_request session |> Lwt.map Result.get_ok)
    ;;

    let delete_request =
      Caqti_request.exec
        Caqti_type.string
        {sql|
      DELETE FROM session_sessions
      WHERE session_sessions.session_key = ?
      |sql}
    ;;

    let delete ctx ~key =
      Database.Service.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec delete_request key |> Lwt.map Result.get_ok)
    ;;

    let clean_request =
      Caqti_request.exec
        Caqti_type.unit
        {sql|
           TRUNCATE session_sessions;
          |sql}
    ;;

    let clean ctx =
      Database.Service.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec clean_request () |> Lwt.map Result.get_ok)
    ;;
  end

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

    let migration () = Migration.(empty "session" |> add_step create_sessions_table)
  end

  let register_migration () = MigrationService.register_migration (Migration.migration ())

  let register_cleaner () =
    let cleaner ctx = Sql.clean ctx in
    Repository.Service.register_cleaner cleaner
  ;;

  let find_all = Sql.find_all
  let find_opt = Sql.find_opt
  let insert = Sql.insert
  let update = Sql.update
  let delete = Sql.delete
end

module MakePostgreSql (MigrationService : Migration.Sig.SERVICE) : Sig.REPO = struct
  module Sql = struct
    module Model = Model

    let find_all_request =
      Caqti_request.find
        Caqti_type.unit
        Model.t
        {sql|
        SELECT
          session_key,
          session_data,
          expire_date
        FROM session_sessions
        |sql}
    ;;

    let find_all ctx =
      Database.Service.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.collect_list find_all_request () |> Lwt.map Result.get_ok)
    ;;

    let find_opt_request =
      Caqti_request.find_opt
        Caqti_type.string
        Model.t
        {sql|
        SELECT
          session_key,
          session_data,
          expire_date
        FROM session_sessions
        WHERE session_sessions.session_key = ?
        |sql}
    ;;

    let find_opt ctx ~key =
      Database.Service.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.find_opt find_opt_request key |> Lwt.map Result.get_ok)
    ;;

    let insert_request =
      Caqti_request.exec
        Model.t
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

    let insert ctx session =
      Database.Service.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec insert_request session |> Lwt.map Result.get_ok)
    ;;

    let update_request =
      Caqti_request.exec
        Model.t
        {sql|
        UPDATE session_sessions SET
          session_data = $2,
          expire_date = $3
        WHERE session_key = $1
        |sql}
    ;;

    let update ctx session =
      Database.Service.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec update_request session |> Lwt.map Result.get_ok)
    ;;

    let delete_request =
      Caqti_request.exec
        Caqti_type.string
        {sql|
      DELETE FROM session_sessions
      WHERE session_sessions.session_key = ?
           |sql}
    ;;

    let delete ctx ~key =
      Database.Service.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec delete_request key |> Lwt.map Result.get_ok)
    ;;

    let clean_request =
      Caqti_request.exec
        Caqti_type.unit
        {sql|
        TRUNCATE TABLE session_sessions CASCADE;
        |sql}
    ;;

    let clean ctx =
      Database.Service.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec clean_request () |> Lwt.map Result.get_ok)
    ;;
  end

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

    let migration () = Migration.(empty "session" |> add_step create_sessions_table)
  end

  let register_migration () = MigrationService.register_migration (Migration.migration ())
  let register_cleaner () = Repository.Service.register_cleaner Sql.clean
  let find_all = Sql.find_all
  let find_opt = Sql.find_opt
  let insert = Sql.insert
  let update = Sql.update
  let delete = Sql.delete
end
