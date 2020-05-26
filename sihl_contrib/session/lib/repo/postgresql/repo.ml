module Sql = struct
  module Session = struct
    open Sihl_session.Model.Session

    let get_all =
      [%rapper
        get_many
          {sql|
        SELECT
          session_key as @string{key},
          session_data as @string{data},
          @ptime{expire_date}
        FROM sessions_sessions
        |sql}
          record_out]

    let get =
      [%rapper
        get_opt
          {sql|
        SELECT
          session_key as @string{key},
          session_data as @string{data},
          @ptime{expire_date}
        FROM sessions_sessions
        WHERE session_sessions.key = %string{key}
        |sql}
          record_out]

    let upsert =
      [%rapper
        execute
          {sql|
        INSERT INTO sessions_sessions (
          session_key,
          session_data,
          expire_date
        ) VALUES (
          %string{key},
          %string{data},
          %ptime{expire_date}
        ) ON CONFLICT (session_key) DO UPDATE SET
        session_data = %string{data}
        |sql}
          record_in]

    let delete =
      [%rapper
        execute
          {sql|
      DELETE FROM sessions_sessions
      WHERE sessions_sessions.key = %string{key}
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
  session_key VARCHAR NOT NULL,
  session_data TEXT NOT NULL,
  expire_date TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE (session_key)
);
|sql}]

  let migration () =
    ("sessions", [ ("create sessions table", create_sessions_table) ])
end

let get_all connection = Sql.Session.get_all connection ()

let get ~key connection = Sql.Session.get connection ~key

let insert session connection =
  Logs.debug (fun m ->
      m "upserting session with key %s" (Sihl_session.Model.Session.key session));
  Sql.Session.upsert connection session

let update session connection = Sql.Session.upsert connection session

let delete ~key connection = Sql.Session.delete connection ~key

let migrate = Migration.migration

let clean connection = Sql.Session.clean connection ()
