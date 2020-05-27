module Sql = struct
  module Session = struct
    module Model = Sihl_session.Repo.Session

    let get_all connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let request =
        Caqti_request.find Caqti_type.unit Model.t
          {sql|
        SELECT
          session_key,
          session_data,
          expire_date
        FROM sessions_sessions
        |sql}
      in
      Connection.collect_list request

    let get connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let request =
        Caqti_request.find_opt Caqti_type.string Model.t
          {sql|
        SELECT
          session_key,
          session_data,
          expire_date
        FROM sessions_sessions
        WHERE session_sessions.key = ?
        |sql}
      in
      Connection.find_opt request

    let upsert connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let request =
        Caqti_request.exec Model.t
          {sql|
        INSERT INTO sessions_sessions (
          session_key,
          session_data,
          expire_date
        ) VALUES (
          ?,
          ?,
          ?
        ) ON CONFLICT (session_key) DO UPDATE SET
        session_data = sessions_sessions.session_data
        |sql}
      in
      Connection.exec request

    let delete connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let request =
        Caqti_request.exec Caqti_type.string
          {sql|
      DELETE FROM sessions_sessions
      WHERE sessions_sessions.key = ?
           |sql}
      in
      Connection.exec request

    let clean connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let request =
        Caqti_request.exec Caqti_type.unit
          {sql|
        TRUNCATE TABLE sessions_sessions CASCADE;
        |sql}
      in
      Connection.exec request ()
  end
end

module Migration = struct
  (* TODO move in some mariadb common module *)
  let migrate str connection =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request = Caqti_request.exec Caqti_type.unit str in
    Connection.exec request

  let create_sessions_table =
    migrate
      {sql|
CREATE TABLE sessions_sessions (
  id serial,
  session_key VARCHAR NOT NULL,
  session_data TEXT NOT NULL,
  expire_date TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE (session_key)
);
|sql}

  let migration () =
    ("sessions", [ ("create sessions table", create_sessions_table) ])
end

let get_all connection = Sql.Session.get_all connection ()

let get ~key connection = Sql.Session.get connection key

let insert session connection = Sql.Session.upsert connection session

let update session connection = Sql.Session.upsert connection session

let delete ~key connection = Sql.Session.delete connection key

let migrate = Migration.migration

let clean connection = Sql.Session.clean connection
