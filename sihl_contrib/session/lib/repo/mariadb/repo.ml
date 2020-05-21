module Sql = struct
  (* TODO move to some common mariadb namespace *)
  let set_fk_check connection status =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.exec Caqti_type.bool
        {sql|
        SET FOREIGN_KEY_CHECKS = ?;
           |sql}
    in
    Connection.exec request status

  module Session = struct
    module Model = struct
      open Sihl_session.Model.Session

      let t =
        let encode m = Ok (m.id, m.data, m.expire_date) in
        let decode (id, data, expire_date) = Ok { id; data; expire_date } in
        Caqti_type.(custom ~encode ~decode (tup3 string string pdate))
    end

    let get connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let request =
        Caqti_request.find Caqti_type.string Model.t
          {sql|
        SELECT
          LOWER(CONCAT(
           SUBSTR(HEX(uuid), 1, 8), '-',
           SUBSTR(HEX(uuid), 9, 4), '-',
           SUBSTR(HEX(uuid), 13, 4), '-',
           SUBSTR(HEX(uuid), 17, 4), '-',
           SUBSTR(HEX(uuid), 21)
           )),
          data,
          expire_date
        FROM sessions_sessions
        WHERE sessions_sessions.uuid = UNHEX(REPLACE(?, '-', ''))
        |sql}
      in
      Connection.find request

    let get_opt connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let request =
        Caqti_request.find Caqti_type.string Model.t
          {sql|
        SELECT
          LOWER(CONCAT(
           SUBSTR(HEX(uuid), 1, 8), '-',
           SUBSTR(HEX(uuid), 9, 4), '-',
           SUBSTR(HEX(uuid), 13, 4), '-',
           SUBSTR(HEX(uuid), 17, 4), '-',
           SUBSTR(HEX(uuid), 21)
           )),
          data,
          expire_date
        FROM sessions_sessions
        WHERE sessions_sessions.uuid = UNHEX(REPLACE(?, '-', ''))
        |sql}
      in
      Connection.find_opt request

    let upsert connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let request =
        Caqti_request.exec Model.t
          {sql|
        INSERT INTO sessions_sessions (
          uuid,
          session_data,
          expire_date
        ) VALUES (
          ?,
          ?,
          ?
        ) ON CONFLICT (uuid) DO UPDATE SET
        session_date = ?
        |sql}
      in
      Connection.exec request

    let delete connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let request =
        Caqti_request.exec Caqti_type.string
          {sql|
      DELETE FROM sessions_sessions
      WHERE sessions_sessions.uuid = ?
      |sql}
      in
      Connection.exec request

    let clean connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let request =
        Caqti_request.exec Caqti_type.unit
          {sql|
TRUNCATE sessions_session;
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
  uuid uuid NOT NULL,
  session_data TEXT NOT NULL,
  expire_date TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE (uuid)
);
|sql}

  let migration () =
    ("sessions", [ ("create sessions table", create_sessions_table) ])
end

let exists ~id connection =
  Sql.Session.get_opt connection id |> Lwt_result.map Option.is_some

let get ~id connection = Sql.Session.get connection id

let insert session connection = Sql.Session.upsert connection session

let update session connection = Sql.Session.upsert connection session

let delete ~id connection = Sql.Session.delete connection id

let migrate = Migration.migration

let clean connection =
  let ( let* ) = Lwt_result.bind in
  let* () = Sql.set_fk_check connection false in
  let* () = Sql.Session.clean connection in
  Sql.set_fk_check connection true
