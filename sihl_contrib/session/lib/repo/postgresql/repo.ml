module Sql = struct
  module Session = struct
    open Sihl_session.Model.Session

    let get =
      [%rapper
        get_one
          {sql|
        SELECT
          uuid as @string{id},
          session_data as @string{data},
          @pdate{expire_date}
        FROM sessions_sessions
        WHERE session_sessions.uuid = %string{id}
        |sql}
          record_out]

    let get_opt =
      [%rapper
        get_opt
          {sql|
        SELECT
          uuid as @string{id},
          session_data as @string{data},
          @pdate{expire_date}
        FROM sessions_sessions
        WHERE session_sessions.uuid = %string{id}
        |sql}
          record_out]

    let upsert =
      [%rapper
        execute
          {sql|
        INSERT INTO sessions_sessions (
          uuid,
          session_data,
          expire_date
        ) VALUES (
          %string{id},
          %string{data},
          %pdate{expire_date}
        ) ON CONFLICT (uuid) DO UPDATE SET
        session_date = %string{data}
        |sql}
          record_in]

    let delete =
      [%rapper
        execute
          {sql|
      DELETE FROM sessions_sessions
      WHERE sessions_sessions.uuid = %string{id}
      |sql}]

    let clean =
      [%rapper
        execute
          {sql|
        TRUNCATE TABLE sessions_sessions CASCADE;
        |sql}]
  end
end

module Migration = struct
  let create_sessions_table =
    [%rapper
      execute
        {sql|
CREATE TABLE sessions_sessions (
  id serial,
  uuid uuid NOT NULL,
  session_data TEXT NOT NULL,
  expire_date TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE (uuid)
);
|sql}]

  let migration () =
    ("sessions", [ ("create sessions table", create_sessions_table) ])
end

let exists ~id connection =
  Sql.Session.get_opt connection ~id |> Lwt_result.map Option.is_some

let get ~id connection = Sql.Session.get connection ~id

let insert session connection = Sql.Session.upsert connection session

let update session connection = Sql.Session.upsert connection session

let delete ~id connection = Sql.Session.delete connection ~id

let migrate = Migration.migration

let clean connection = Sql.Session.clean connection ()
