module Sql = struct
  module Session = struct
    module Model = Sihl.Session

    let get_all connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let request =
        Caqti_request.find Caqti_type.unit Model.t
          {sql|
        SELECT
          session_key,
          session_data,
          expire_date
        FROM session_sessions
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
        FROM session_sessions
        WHERE session_sessions.session_key = ?
        |sql}
      in
      Connection.find_opt request

    let upsert connection =
      (* TODO split up into insert and update *)
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let request =
        Caqti_request.exec Model.t
          {sql|
        INSERT INTO session_sessions (
          session_key,
          session_data,
          expire_date
        ) VALUES (
          ?,
          ?,
          ?
        ) ON DUPLICATE KEY UPDATE
        session_data = VALUES(session_data)
        |sql}
      in
      Connection.exec request

    let delete connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let request =
        Caqti_request.exec Caqti_type.string
          {sql|
      DELETE FROM session_sessions
      WHERE session_sessions.session_key = ?
      |sql}
      in
      Connection.exec request

    let clean connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let request =
        Caqti_request.exec Caqti_type.unit
          {sql|
           TRUNCATE session_sessions;
          |sql}
      in
      Connection.exec request ()
  end
end

module Migration = struct
  let create_sessions_table =
    Sihl.Migration.create_step ~label:"create sessions table"
      {sql|
CREATE TABLE session_sessions (
  id serial,
  session_key VARCHAR(64) NOT NULL,
  session_data VARCHAR(1024) NOT NULL,
  expire_date TIMESTAMP NOT NULL,
  PRIMARY KEY(id),
  CONSTRAINT unique_key UNIQUE(session_key)
);
|sql}

  let migration () =
    Sihl.Migration.(empty "session" |> add_step create_sessions_table)
end

let get_all connection = Sql.Session.get_all connection ()

let get ~key connection = Sql.Session.get connection key

let insert session connection = Sql.Session.upsert connection session

let update session connection = Sql.Session.upsert connection session

let delete ~key connection = Sql.Session.delete connection key

let migrate = Migration.migration

let clean connection =
  let ( let* ) = Lwt_result.bind in
  let* () = Sihl.Repo.set_fk_check connection false in
  let* () = Sql.Session.clean connection in
  Sihl.Repo.set_fk_check connection true
