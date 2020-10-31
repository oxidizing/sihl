open Lwt.Syntax

let log_src = Logs.Src.create ~doc:"session" "sihl.service.session"

module Logs = (val Logs.src_log log_src : Logs.LOG)

let ctx_key : string Core.Ctx.key = Core.Ctx.create_key ()

module Make (Repo : Sig.REPO) : Sig.SERVICE = struct
  let make ?expire_date now =
    let open Model in
    match expire_date, default_expiration_date now with
    | Some expire_date, _ ->
      Some { key = Core.Random.base64 ~nr:10; data = Map.empty; expire_date }
    | None, Some expire_date ->
      Some { key = Core.Random.base64 ~nr:10; data = Map.empty; expire_date }
    | None, None -> None
  ;;

  let create ctx data =
    let empty_session =
      match make (Ptime_clock.now ()) with
      | Some session -> session
      | None ->
        Logs.err (fun m ->
            m "SESSION: Can not create session, failed to create validity time");
        raise (Model.Exception "Can not set session validity time")
    in
    let session =
      List.fold_left
        (fun session (key, value) -> Model.set ~key ~value session)
        empty_session
        data
    in
    let* () = Repo.insert ctx session in
    Lwt.return session
  ;;

  let find_opt = Repo.find_opt

  let find ctx ~key =
    let* session = Repo.find_opt ctx ~key in
    match session with
    | Some session -> Lwt.return session
    | None ->
      Logs.err (fun m -> m "SESSION: Session with key %s not found in database" key);
      raise (Model.Exception "Session not found")
  ;;

  let find_all = Repo.find_all

  let set ctx session ~key ~value =
    let session_key = Model.key session in
    let* session = find ctx ~key:session_key in
    let session = Model.set ~key ~value session in
    Repo.update ctx session
  ;;

  let unset ctx session ~key =
    let session_key = Model.key session in
    let* session = find ctx ~key:session_key in
    let session = Model.remove ~key session in
    Repo.update ctx session
  ;;

  let get ctx session ~key =
    let session_key = Model.key session in
    let* session = find ctx ~key:session_key in
    Model.get key session |> Lwt.return
  ;;

  let start ctx =
    Repo.register_migration ();
    Repo.register_cleaner ();
    Lwt.return ctx
  ;;

  let stop _ = Lwt.return ()
  let lifecycle = Core.Container.Lifecycle.create "session" ~start ~stop

  let configure configuration =
    let configuration = Core.Configuration.make configuration in
    Core.Container.Service.create ~configuration lifecycle
  ;;
end

module Repo = struct
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
            Connection.collect_list find_all_request ())
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
            Connection.find_opt find_opt_request key)
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
            Connection.exec insert_request session)
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
            Connection.exec update_request session)
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
            Connection.exec delete_request key)
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
            Connection.exec clean_request ())
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

    let register_migration () = MigrationService.register (Migration.migration ())

    let register_cleaner () =
      let cleaner ctx =
        Database.Service.with_disabled_fk_check ctx (fun ctx -> Sql.clean ctx)
      in
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
            Connection.collect_list find_all_request ())
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
            Connection.find_opt find_opt_request key)
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
            Connection.exec insert_request session)
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
            Connection.exec update_request session)
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
            Connection.exec delete_request key)
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
            Connection.exec clean_request ())
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

    let register_migration () = MigrationService.register (Migration.migration ())
    let register_cleaner () = Repository.Service.register_cleaner Sql.clean
    let find_all = Sql.find_all
    let find_opt = Sql.find_opt
    let insert = Sql.insert
    let update = Sql.update
    let delete = Sql.delete
  end
end
