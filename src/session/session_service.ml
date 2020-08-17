open Base

let ( let* ) = Lwt_result.bind

module Make (Repo : Session_sig.REPO) : Session_sig.SERVICE = struct
  let lifecycle =
    Core.Container.Lifecycle.make "session"
      (fun ctx ->
        (let* () = Repo.register_migration ctx in
         Repo.register_cleaner ctx)
        |> Lwt.map Result.ok_or_failwith
        |> Lwt.map (fun () -> ctx))
      (fun _ -> Lwt.return ())

  let require_session_key ctx =
    Core.Ctx.find Session_sig.ctx_session_key ctx
    |> Result.of_option ~error:"SESSION: No session found in context"
    |> Lwt.return

  let set_value ctx ~key ~value =
    let* session_key = require_session_key ctx in
    let* session = Repo.get ctx ~key:session_key in
    match session with
    | None ->
        Lwt.return
        @@ Ok
             (Logs.warn (fun m ->
                  m "SESSION: Provided session key has no session in DB"))
    | Some session ->
        let session = Session_core.set ~key ~value session in
        Repo.update ctx session

  let remove_value ctx ~key =
    let* session_key = require_session_key ctx in
    let* session = Repo.get ctx ~key:session_key in
    match session with
    | None ->
        Lwt.return
        @@ Ok
             (Logs.warn (fun m ->
                  m "SESSION: Provided session key has no session in DB"))
    | Some session ->
        let session = Session_core.remove ~key session in
        Repo.update ctx session

  let get_value ctx ~key =
    let* session_key = require_session_key ctx in
    let* session = Repo.get ctx ~key:session_key in
    match session with
    | None ->
        Logs.warn (fun m ->
            m "SESSION: Provided session key has no session in DB");
        Lwt.return @@ Ok None
    | Some session ->
        Session_core.get key session |> Result.return |> Lwt.return

  let get_session ctx ~key = Repo.get ctx ~key

  let get_all_sessions ctx = Repo.get_all ctx

  let insert_session ctx ~session = Repo.insert ctx session

  let create ctx data =
    let empty_session = Session_core.make (Ptime_clock.now ()) in
    let session =
      List.fold data ~init:empty_session ~f:(fun session (key, value) ->
          Session_core.set ~key ~value session)
    in
    let* () = insert_session ctx ~session in
    Lwt_result.return session
end

module Repo = struct
  module MakeMariaDb
      (DbService : Data.Db.Sig.SERVICE)
      (RepoService : Data.Repo.Sig.SERVICE)
      (MigrationService : Data.Migration.Sig.SERVICE) : Session_sig.REPO =
  struct
    module Sql = struct
      module Model = Session_core

      let get_all_request =
        Caqti_request.find Caqti_type.unit Model.t
          {sql|
        SELECT
          session_key,
          session_data,
          expire_date
        FROM session_sessions
        |sql}

      let get_all connection =
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.collect_list get_all_request ()
        |> Lwt_result.map_err Caqti_error.show

      let get_request =
        Caqti_request.find_opt Caqti_type.string Model.t
          {sql|
        SELECT
          session_key,
          session_data,
          expire_date
        FROM session_sessions
        WHERE session_sessions.session_key = ?
        |sql}

      let get connection ~id =
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.find_opt get_request id
        |> Lwt_result.map_err Caqti_error.show

      let insert_request =
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
        )
        |sql}

      let insert connection ~session =
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec insert_request session
        |> Lwt_result.map_err Caqti_error.show

      let update_request =
        Caqti_request.exec Model.t
          {sql|
        UPDATE session_sessions SET
          session_data = $2,
          expire_date = $3
        WHERE session_key = $1
        |sql}

      let update connection ~session =
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec update_request session
        |> Lwt_result.map_err Caqti_error.show

      let delete_request =
        Caqti_request.exec Caqti_type.string
          {sql|
      DELETE FROM session_sessions
      WHERE session_sessions.session_key = ?
      |sql}

      let delete connection ~id =
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec delete_request id |> Lwt_result.map_err Caqti_error.show

      let clean_request =
        Caqti_request.exec Caqti_type.unit
          {sql|
           TRUNCATE session_sessions;
          |sql}

      let clean connection =
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec clean_request () |> Lwt_result.map_err Caqti_error.show
    end

    module Migration = struct
      let create_sessions_table =
        Data.Migration.create_step ~label:"create sessions table"
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

      let migration () =
        Data.Migration.(empty "session" |> add_step create_sessions_table)
    end

    let register_migration ctx =
      MigrationService.register ctx (Migration.migration ())

    let register_cleaner ctx =
      let cleaner ctx =
        let ( let* ) = Lwt_result.bind in
        let* () = Data.Db.set_fk_check ~check:false |> DbService.query ctx in
        let* () = Sql.clean |> DbService.query ctx in
        Data.Db.set_fk_check ~check:true |> DbService.query ctx
      in
      RepoService.register_cleaner ctx cleaner

    let get_all ctx = Sql.get_all |> DbService.query ctx

    let get ctx ~key = Sql.get ~id:key |> DbService.query ctx

    let insert ctx session = Sql.insert ~session |> DbService.query ctx

    let update ctx session = Sql.update ~session |> DbService.query ctx

    let delete ctx ~key = Sql.delete ~id:key |> DbService.query ctx
  end

  module MakePostgreSql
      (DbService : Data.Db.Sig.SERVICE)
      (RepoService : Data.Repo.Sig.SERVICE)
      (MigrationService : Data.Migration.Sig.SERVICE) : Session_sig.REPO =
  struct
    module Sql = struct
      module Model = Session_core

      let get_all_request =
        Caqti_request.find Caqti_type.unit Model.t
          {sql|
        SELECT
          session_key,
          session_data,
          expire_date
        FROM session_sessions
        |sql}

      let get_all connection =
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.collect_list get_all_request ()
        |> Lwt_result.map_err Caqti_error.show

      let get_request =
        Caqti_request.find_opt Caqti_type.string Model.t
          {sql|
        SELECT
          session_key,
          session_data,
          expire_date
        FROM session_sessions
        WHERE session_sessions.session_key = ?
        |sql}

      let get connection ~id =
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.find_opt get_request id
        |> Lwt_result.map_err Caqti_error.show

      let insert_request =
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
        )
        |sql}

      let insert connection ~session =
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec insert_request session
        |> Lwt_result.map_err Caqti_error.show

      let update_request =
        Caqti_request.exec Model.t
          {sql|
        UPDATE session_sessions SET
          session_data = $2,
          expire_date = $3
        WHERE session_key = $1
        |sql}

      let update connection ~session =
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec update_request session
        |> Lwt_result.map_err Caqti_error.show

      let delete_request =
        Caqti_request.exec Caqti_type.string
          {sql|
      DELETE FROM session_sessions
      WHERE session_sessions.session_key = ?
           |sql}

      let delete connection ~id =
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec delete_request id |> Lwt_result.map_err Caqti_error.show

      let clean_request =
        Caqti_request.exec Caqti_type.unit
          {sql|
        TRUNCATE TABLE session_sessions CASCADE;
        |sql}

      let clean connection =
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec clean_request () |> Lwt_result.map_err Caqti_error.show
    end

    module Migration = struct
      let create_sessions_table =
        Data.Migration.create_step ~label:"create sessions table"
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

      let migration () =
        Data.Migration.(empty "session" |> add_step create_sessions_table)
    end

    let register_migration ctx =
      MigrationService.register ctx (Migration.migration ())

    let register_cleaner ctx =
      let cleaner ctx = Sql.clean |> DbService.query ctx in
      RepoService.register_cleaner ctx cleaner

    let get_all ctx = Sql.get_all |> DbService.query ctx

    let get ctx ~key = Sql.get ~id:key |> DbService.query ctx

    let insert ctx session = Sql.insert ~session |> DbService.query ctx

    let update ctx session = Sql.update ~session |> DbService.query ctx

    let delete ctx ~key = Sql.delete ~id:key |> DbService.query ctx
  end
end
