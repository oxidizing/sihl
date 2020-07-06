open Base

let ( let* ) = Lwt_result.bind

module Make
    (MigrationService : Data.Migration.Sig.SERVICE)
    (SessionRepo : Session_sig.REPO) : Session_sig.SERVICE = struct
  let on_bind ctx =
    let* () = MigrationService.register ctx (SessionRepo.migrate ()) in
    Data.Repo.register_cleaner ctx SessionRepo.clean

  let on_start _ = Lwt.return @@ Ok ()

  let on_stop _ = Lwt.return @@ Ok ()

  let require_session_key ctx =
    Core.Ctx.find Session_sig.ctx_session_key ctx
    |> Result.of_option ~error:"SESSION: No session found in context"
    |> Lwt.return

  let set_value ctx ~key ~value =
    Logs.debug (fun m -> m "four %s" (Core.Ctx.id ctx));
    let* session_key = require_session_key ctx in
    let* session = SessionRepo.get ~key:session_key |> Data.Db.query ctx in
    match session with
    | None ->
        Lwt.return
        @@ Ok
             (Logs.warn (fun m ->
                  m "SESSION: Provided session key has no session in DB"))
    | Some session ->
        let session = Session_model.set ~key ~value session in
        SessionRepo.insert session |> Data.Db.query ctx

  let remove_value ctx ~key =
    let* session_key = require_session_key ctx in
    let* session = SessionRepo.get ~key:session_key |> Data.Db.query ctx in
    match session with
    | None ->
        Lwt.return
        @@ Ok
             (Logs.warn (fun m ->
                  m "SESSION: Provided session key has no session in DB"))
    | Some session ->
        let session = Session_model.remove ~key session in
        SessionRepo.insert session |> Data.Db.query ctx

  let get_value ctx ~key =
    let* session_key = require_session_key ctx in
    let* session = SessionRepo.get ~key:session_key |> Data.Db.query ctx in
    match session with
    | None ->
        Logs.warn (fun m ->
            m "SESSION: Provided session key has no session in DB");
        Lwt.return @@ Ok None
    | Some session ->
        Session_model.get key session |> Result.return |> Lwt.return

  let get_session ctx ~key = SessionRepo.get ~key |> Data.Db.query ctx

  let get_all_sessions ctx = SessionRepo.get_all |> Data.Db.query ctx

  let insert_session ctx ~session =
    SessionRepo.insert session |> Data.Db.query ctx
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
        Connection.collect_list request ()
        |> Lwt_result.map_err Caqti_error.show

      let get connection id =
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
        Connection.find_opt request id |> Lwt_result.map_err Caqti_error.show

      let upsert connection model =
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
        Connection.exec request model |> Lwt_result.map_err Caqti_error.show

      let delete connection id =
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        let request =
          Caqti_request.exec Caqti_type.string
            {sql|
      DELETE FROM session_sessions
      WHERE session_sessions.session_key = ?
      |sql}
        in
        Connection.exec request id |> Lwt_result.map_err Caqti_error.show

      let clean connection =
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        let request =
          Caqti_request.exec Caqti_type.unit
            {sql|
           TRUNCATE session_sessions;
          |sql}
        in
        Connection.exec request () |> Lwt_result.map_err Caqti_error.show
    end
  end

  module Migration = struct
    let create_sessions_table =
      Data.Migration.create_step ~label:"create sessions table"
        {sql|
CREATE TABLE session_sessions (
  id serial,
  session_key VARCHAR(64) NOT NULL,
  session_data VARCHAR(1024) NOT NULL,
  expire_date TIMESTAMP NOT NULL,
  PRIMARY KEY(id),
  CONSTRAINT unique_key UNIQUE(session_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
|sql}

    let migration () =
      Data.Migration.(empty "session" |> add_step create_sessions_table)
  end

  let get_all connection = Sql.Session.get_all connection

  let get ~key connection = Sql.Session.get connection key

  let insert session connection = Sql.Session.upsert connection session

  let update session connection = Sql.Session.upsert connection session

  let delete ~key connection = Sql.Session.delete connection key

  let migrate = Migration.migration

  let clean connection =
    let ( let* ) = Lwt_result.bind in
    let* () = Data.Db.set_fk_check connection ~check:false in
    let* () = Sql.Session.clean connection in
    Data.Db.set_fk_check connection ~check:true
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
        Connection.collect_list request ()
        |> Lwt_result.map_err Caqti_error.show

      let get connection id =
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
        Connection.find_opt request id |> Lwt_result.map_err Caqti_error.show

      let upsert connection model =
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
        Connection.exec request model |> Lwt_result.map_err Caqti_error.show

      let delete connection id =
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        let request =
          Caqti_request.exec Caqti_type.string
            {sql|
      DELETE FROM session_sessions
      WHERE session_sessions.session_key = ?
           |sql}
        in
        Connection.exec request id |> Lwt_result.map_err Caqti_error.show

      let clean connection =
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        let request =
          Caqti_request.exec Caqti_type.unit
            {sql|
        TRUNCATE TABLE session_sessions CASCADE;
        |sql}
        in
        Connection.exec request () |> Lwt_result.map_err Caqti_error.show
    end
  end

  module Migration = struct
    let create_sessions_table =
      Data.Migration.create_step ~label:"create sessions table"
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
      Data.Migration.(empty "session" |> add_step create_sessions_table)
  end

  let get_all connection = Sql.Session.get_all connection

  let get ~key connection = Sql.Session.get connection key

  let insert session connection = Sql.Session.upsert connection session

  let update session connection = Sql.Session.upsert connection session

  let delete ~key connection = Sql.Session.delete connection key

  let migrate = Migration.migration

  let clean connection = Sql.Session.clean connection
end

module MariaDb = Make (Data.Migration.Service.MariaDb) (SessionRepoMariaDb)

let mariadb =
  Core.Container.create_binding Session_sig.key (module MariaDb) (module MariaDb)

module PostgreSql =
  Make (Data.Migration.Service.PostgreSql) (SessionRepoPostgreSql)

let postgresql =
  Core.Container.create_binding Session_sig.key
    (module PostgreSql)
    (module PostgreSql)
