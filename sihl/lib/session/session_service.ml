open Base

let ( let* ) = Lwt_result.bind

module Make
    (MigrationService : Migration.Service.SERVICE)
    (SessionRepo : Session_sig.REPO) : Session_sig.SERVICE = struct
  let on_bind req =
    let* () = MigrationService.register req (SessionRepo.migrate ()) in
    Repo.register_cleaner req SessionRepo.clean

  let on_start _ = Lwt.return @@ Ok ()

  let on_stop _ = Lwt.return @@ Ok ()

  let set_value req ~key ~value =
    let session_key =
      match
        Opium.Hmap.find Session_sig.middleware_key (Opium.Std.Request.env req)
      with
      | Some session -> session
      | None ->
          Core.Err.raise_server
            "Session not found in Request.env, have you applied the \
             Sihl.Middleware.session?"
    in
    let* session = SessionRepo.get ~key:session_key |> Core.Db.query_db req in
    match session with
    | None ->
        Lwt.return
        @@ Ok
             (Logs.warn (fun m ->
                  m "SESSION: Provided session key has no session in DB"))
    | Some session ->
        let session = Session_model.set ~key ~value session in
        SessionRepo.insert session |> Core.Db.query_db req

  let remove_value req ~key =
    let session_key =
      match
        Opium.Hmap.find Session_sig.middleware_key (Opium.Std.Request.env req)
      with
      | Some session -> session
      | None ->
          Core.Err.raise_server
            "Session not found in Request.env, have you applied the \
             Sihl.Middleware.session?"
    in
    let* session = SessionRepo.get ~key:session_key |> Core.Db.query_db req in
    match session with
    | None ->
        Lwt.return
        @@ Ok
             (Logs.warn (fun m ->
                  m "SESSION: Provided session key has no session in DB"))
    | Some session ->
        let session = Session_model.remove ~key session in
        SessionRepo.insert session |> Core.Db.query_db req

  let get_value req ~key =
    let session_key =
      match
        Opium.Hmap.find Session_sig.middleware_key (Opium.Std.Request.env req)
      with
      | Some session -> session
      | None ->
          Core.Err.raise_server
            "Session not found in Request.env, have you applied the \
             Sihl.Middleware.session?"
    in
    let* session = SessionRepo.get ~key:session_key |> Core.Db.query_db req in
    match session with
    | None ->
        Logs.warn (fun m ->
            m "SESSION: Provided session key has no session in DB");
        Lwt.return @@ Ok None
    | Some session ->
        Session_model.get key session |> Result.return |> Lwt.return

  let get_session req ~key = SessionRepo.get ~key |> Core.Db.query_db req

  let get_all_sessions req = SessionRepo.get_all |> Core.Db.query_db req

  let insert_session req ~session =
    SessionRepo.insert session |> Core.Db.query_db req
end

module SessionRepoMariaDb = struct
  module Sql = struct
    module Session = struct
      module Model = Session_model

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
      Migration.create_step ~label:"create sessions table"
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
      Migration.(empty "session" |> add_step create_sessions_table)
  end

  let get_all connection = Sql.Session.get_all connection ()

  let get ~key connection = Sql.Session.get connection key

  let insert session connection = Sql.Session.upsert connection session

  let update session connection = Sql.Session.upsert connection session

  let delete ~key connection = Sql.Session.delete connection key

  let migrate = Migration.migration

  let clean connection =
    let ( let* ) = Lwt_result.bind in
    let* () = Repo.set_fk_check connection false in
    let* () = Sql.Session.clean connection in
    Repo.set_fk_check connection true
end

module SessionRepoPostgreSql = struct
  module Sql = struct
    module Session = struct
      module Model = Session_model

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
        ) ON CONFLICT (session_key) DO UPDATE SET
        session_data = EXCLUDED.session_data
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
        TRUNCATE TABLE session_sessions CASCADE;
        |sql}
        in
        Connection.exec request ()
    end
  end

  module Migration = struct
    let create_sessions_table =
      Migration.create_step ~label:"create sessions table"
        {sql|
CREATE TABLE session_sessions (
  id serial,
  session_key VARCHAR NOT NULL,
  session_data TEXT NOT NULL,
  expire_date TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE (session_key)
);
|sql}

    let migration () =
      Migration.(empty "session" |> add_step create_sessions_table)
  end

  let get_all connection = Sql.Session.get_all connection ()

  let get ~key connection = Sql.Session.get connection key

  let insert session connection = Sql.Session.upsert connection session

  let update session connection = Sql.Session.upsert connection session

  let delete ~key connection = Sql.Session.delete connection key

  let migrate = Migration.migration

  let clean connection = Sql.Session.clean connection
end

module MariaDb = Make (Migration.Service.MariaDb) (SessionRepoMariaDb)

let mariadb =
  Core.Container.create_binding Session_sig.key (module MariaDb) (module MariaDb)

module PostgreSql = Make (Migration.Service.PostgreSql) (SessionRepoPostgreSql)

let postgresql =
  Core.Container.create_binding Session_sig.key
    (module PostgreSql)
    (module PostgreSql)
