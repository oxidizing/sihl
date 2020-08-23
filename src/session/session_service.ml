open Base
open Lwt.Syntax

let ctx_key : string Core.Ctx.key = Core.Ctx.create_key ()

exception SessionNotFound of string

module Make (Log : Log_sig.SERVICE) (Repo : Session_sig.REPO) :
  Session_sig.SERVICE = struct
  let lifecycle =
    Core.Container.Lifecycle.make "session"
      (fun ctx ->
        (let* () = Repo.register_migration ctx in
         Repo.register_cleaner ctx)
        |> Lwt.map (fun () -> ctx))
      (fun _ -> Lwt.return ())

  let add_to_ctx session ctx =
    Core.Ctx.add ctx_key (Session_core.key session) ctx

  let require_session_key ctx =
    match Core.Ctx.find ctx_key ctx with
    | None ->
        Log.err (fun m -> m "SESSION: No session found in context");
        Log.info (fun m -> m "HINT: Have you applied the session middleware?");
        raise (SessionNotFound "No session found in context")
    | Some session -> session

  let create ctx data =
    let empty_session = Session_core.make (Ptime_clock.now ()) in
    let session =
      List.fold data ~init:empty_session ~f:(fun session (key, value) ->
          Session_core.set ~key ~value session)
    in
    let* () = Repo.insert ctx session in
    Lwt.return session

  let find_opt = Repo.find_opt

  let find ctx ~key =
    let* session = Repo.find_opt ctx ~key in
    match session with
    | Some session -> Lwt.return session
    | None ->
        Log.err (fun m ->
            m "SESSION: Session with key %s not found in database" key);
        raise (SessionNotFound "Session not found")

  let find_all = Repo.find_all

  let set ctx ~key ~value =
    let session_key = require_session_key ctx in
    let* session = find ctx ~key:session_key in
    let session = Session_core.set ~key ~value session in
    Repo.update ctx session

  let unset ctx ~key =
    let session_key = require_session_key ctx in
    let* session = find ctx ~key:session_key in
    let session = Session_core.remove ~key session in
    Repo.update ctx session

  let get ctx ~key =
    let session_key = require_session_key ctx in
    let* session = find ctx ~key:session_key in
    Session_core.get key session |> Lwt.return
end

module Repo = struct
  module MakeMariaDb
      (DbService : Data.Db.Sig.SERVICE)
      (RepoService : Data.Repo.Sig.SERVICE)
      (MigrationService : Data.Migration.Sig.SERVICE) : Session_sig.REPO =
  struct
    module Sql = struct
      module Model = Session_core

      let find_all_request =
        Caqti_request.find Caqti_type.unit Model.t
          {sql|
        SELECT
          session_key,
          session_data,
          expire_date
        FROM session_sessions
        |sql}

      let find_all ctx =
        DbService.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
            Connection.collect_list find_all_request ())

      let find_opt_request =
        Caqti_request.find_opt Caqti_type.string Model.t
          {sql|
        SELECT
          session_key,
          session_data,
          expire_date
        FROM session_sessions
        WHERE session_sessions.session_key = ?
        |sql}

      let find_opt ctx ~key =
        DbService.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
            Connection.find_opt find_opt_request key)

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

      let insert ctx session =
        DbService.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
            Connection.exec insert_request session)

      let update_request =
        Caqti_request.exec Model.t
          {sql|
        UPDATE session_sessions SET
          session_data = $2,
          expire_date = $3
        WHERE session_key = $1
        |sql}

      let update ctx session =
        DbService.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
            Connection.exec update_request session)

      let delete_request =
        Caqti_request.exec Caqti_type.string
          {sql|
      DELETE FROM session_sessions
      WHERE session_sessions.session_key = ?
      |sql}

      let delete ctx ~key =
        DbService.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
            Connection.exec delete_request key)

      let clean_request =
        Caqti_request.exec Caqti_type.unit
          {sql|
           TRUNCATE session_sessions;
          |sql}

      let clean ctx =
        DbService.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
            Connection.exec clean_request ())
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
        let* () = DbService.set_fk_check ctx ~check:false in
        let* () = Sql.clean ctx in
        DbService.set_fk_check ctx ~check:true
      in
      RepoService.register_cleaner ctx cleaner

    let find_all = Sql.find_all

    let find_opt = Sql.find_opt

    let insert = Sql.insert

    let update = Sql.update

    let delete = Sql.delete
  end

  module MakePostgreSql
      (DbService : Data.Db.Sig.SERVICE)
      (RepoService : Data.Repo.Sig.SERVICE)
      (MigrationService : Data.Migration.Sig.SERVICE) : Session_sig.REPO =
  struct
    module Sql = struct
      module Model = Session_core

      let find_all_request =
        Caqti_request.find Caqti_type.unit Model.t
          {sql|
        SELECT
          session_key,
          session_data,
          expire_date
        FROM session_sessions
        |sql}

      let find_all ctx =
        DbService.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
            Connection.collect_list find_all_request ())

      let find_opt_request =
        Caqti_request.find_opt Caqti_type.string Model.t
          {sql|
        SELECT
          session_key,
          session_data,
          expire_date
        FROM session_sessions
        WHERE session_sessions.session_key = ?
        |sql}

      let find_opt ctx ~key =
        DbService.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
            Connection.find_opt find_opt_request key)

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

      let insert ctx session =
        DbService.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
            Connection.exec insert_request session)

      let update_request =
        Caqti_request.exec Model.t
          {sql|
        UPDATE session_sessions SET
          session_data = $2,
          expire_date = $3
        WHERE session_key = $1
        |sql}

      let update ctx session =
        DbService.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
            Connection.exec update_request session)

      let delete_request =
        Caqti_request.exec Caqti_type.string
          {sql|
      DELETE FROM session_sessions
      WHERE session_sessions.session_key = ?
           |sql}

      let delete ctx ~key =
        DbService.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
            Connection.exec delete_request key)

      let clean_request =
        Caqti_request.exec Caqti_type.unit
          {sql|
        TRUNCATE TABLE session_sessions CASCADE;
        |sql}

      let clean ctx =
        DbService.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
            Connection.exec clean_request ())
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

    let register_cleaner ctx = RepoService.register_cleaner ctx Sql.clean

    let find_all = Sql.find_all

    let find_opt = Sql.find_opt

    let insert = Sql.insert

    let update = Sql.update

    let delete = Sql.delete
  end
end
