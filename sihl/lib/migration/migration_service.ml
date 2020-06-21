open Base
open Migration_sig
module Model = Migration_model

let ( let* ) = Lwt_result.bind

module Make (MigrationRepo : REPO) : SERVICE = struct
  let on_bind _ = Lwt.return @@ Ok ()

  let on_start _ = Lwt.return @@ Ok ()

  let on_stop _ = Lwt.return @@ Ok ()

  let setup c =
    Logs.debug (fun m -> m "MIGRATION: Setting up table if not exists");
    MigrationRepo.create_table_if_not_exists |> Core.Db.query_db_connection c

  let has c ~namespace =
    let* result =
      MigrationRepo.get ~namespace |> Core.Db.query_db_connection c
    in
    Lwt_result.return (Option.is_some result)

  let get c ~namespace =
    let* state =
      MigrationRepo.get ~namespace |> Core.Db.query_db_connection c
    in
    Lwt.return
    @@
    match state with
    | Some state -> Ok state
    | None ->
        Error
          (Printf.sprintf "could not get migration state for namespace %s"
             namespace)

  let upsert c state =
    MigrationRepo.upsert ~state |> Core.Db.query_db_connection c

  let mark_dirty c ~namespace =
    let* state = get c ~namespace in
    let dirty_state = Model.mark_dirty state in
    let* () = upsert c dirty_state in
    Lwt.return @@ Ok dirty_state

  let mark_clean c ~namespace =
    let* state = get c ~namespace in
    let clean_state = Model.mark_clean state in
    let* () = upsert c clean_state in
    Lwt.return @@ Ok clean_state

  let increment c ~namespace =
    let* state = get c ~namespace in
    let updated_state = Model.increment state in
    let* () = upsert c updated_state in
    Lwt.return @@ Ok updated_state

  let register _ migration =
    Migration_model.Registry.register migration;
    Lwt.return @@ Ok ()

  let get_migrations _ = Lwt.return @@ Ok (Migration_model.Registry.get_all ())

  let execute_steps migration conn =
    let (module Service : SERVICE) = Core.Container.fetch_service_exn key in
    let module Connection = (val conn : Caqti_lwt.CONNECTION) in
    let namespace, steps = migration in
    let open Lwt in
    let rec run steps conn =
      match steps with
      | [] -> Lwt_result.return ()
      | Model.Migration.{ label; statement; check_fk = true } :: steps -> (
          Logs.debug (fun m -> m "MIGRATION: Running %s" label);
          let req = Caqti_request.exec Caqti_type.unit statement in
          Connection.exec req () >>= function
          | Ok () ->
              Logs.debug (fun m -> m "MIGRATION: Ran %s" label);
              let* _ = increment conn ~namespace in
              run steps conn
          | Error err ->
              let msg =
                Printf.sprintf
                  "MIGRATION: Error while running migration for %s %s" namespace
                  (Caqti_error.show err)
              in
              Logs.err (fun m -> m "%s" msg);
              Lwt.return @@ Error msg )
      | { label; statement; check_fk = false } :: steps -> (
          let ( let* ) = Lwt.bind in
          let* _ = Repo.set_fk_check conn false in
          Logs.debug (fun m ->
              m "MIGRATION: Running %s without fk checks" label);
          let req = Caqti_request.exec Caqti_type.unit statement in
          Connection.exec req () >>= function
          | Ok () ->
              let* _ = Repo.set_fk_check conn true in
              Logs.debug (fun m -> m "MIGRATION: Ran %s" label);
              let* _ = increment conn ~namespace in
              run steps conn
          | Error err ->
              let* _ = Repo.set_fk_check conn true in
              let msg =
                Printf.sprintf
                  "MIGRATION: Error while running migration for %s %s" namespace
                  (Caqti_error.show err)
              in
              Logs.err (fun m -> m "%s" msg);
              Lwt.return @@ Error msg )
    in
    let () =
      match List.length steps with
      | 0 ->
          Logs.debug (fun m ->
              m "MIGRATION: No migrations to apply for %s" namespace)
      | n ->
          Logs.debug (fun m ->
              m "MIGRATION: Applying %i migrations for %s" n namespace)
    in
    run steps conn

  let execute_migration migration conn =
    let (module Service : SERVICE) = Core.Container.fetch_service_exn key in
    let namespace, _ = migration in
    Logs.debug (fun m -> m "MIGRATION: Execute migrations for app %s" namespace);
    let* () = setup conn in
    let* has_state = has conn ~namespace in
    let* state =
      if has_state then
        let* state = get conn ~namespace in
        if Model.dirty state then (
          let msg =
            Printf.sprintf
              "Dirty migration found for app %s, has to be fixed manually"
              namespace
          in
          Logs.err (fun m -> m "MIGRATION: %s" msg);
          failwith msg )
        else mark_dirty conn ~namespace
      else (
        Logs.debug (fun m ->
            m "MIGRATION: Setting up table for %s app" namespace);
        let state = Model.create ~namespace in
        let* () = upsert conn state in
        Lwt.return @@ Ok state )
    in
    let migration_to_apply = Model.steps_to_apply migration state in
    let* () = execute_steps migration_to_apply conn in
    let* _ = mark_clean conn ~namespace in
    Lwt.return @@ Ok ()

  (* TODO We just need this because we leak caqti_errors everywhere. Once we hide
     different caqti_errors, we can get rid of it and use ('a, string) Result.t everywhere *)
  let to_caqti_error result =
    result
    |> Result.map_error ~f:(fun err ->
           Caqti_error.connect_failed ~uri:Uri.empty (Caqti_error.Msg err))

  (* TODO gracefully try to disable and enable fk keys *)
  let execute migrations =
    let n = List.length migrations in
    if n > 0 then
      Logs.debug (fun m ->
          m "MIGRATION: Executing %i migrations" (List.length migrations))
    else Logs.debug (fun m -> m "MIGRATION: No migrations to execute");
    let open Lwt in
    let rec run migrations conn =
      match migrations with
      | [] -> Lwt_result.return ()
      | migration :: migrations -> (
          execute_migration migration conn >>= function
          | Ok () -> run migrations conn
          | Error err -> return (Error err) )
    in
    let pool = Core.Db.connect () in
    let result =
      Caqti_lwt.Pool.use
        (fun conn -> run migrations conn >|= to_caqti_error)
        pool
    in
    result |> Lwt_result.map_err Caqti_error.show
end

module RepoMariaDb = struct
  let create_table_if_not_exists connection =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.exec Caqti_type.unit
        {sql|
CREATE TABLE IF NOT EXISTS core_migration_state (
  namespace VARCHAR(128) NOT NULL,
  version INTEGER,
  dirty BOOL NOT NULL,
  PRIMARY KEY (namespace)
);
 |sql}
    in
    Connection.exec request ()

  let get connection ~namespace =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.find_opt Caqti_type.string
        Caqti_type.(tup3 string int bool)
        {sql|
SELECT
  namespace,
  version,
  dirty
FROM core_migration_state
WHERE namespace = ?;
|sql}
    in
    let* result = Connection.find_opt request namespace in
    Lwt.return @@ Ok (result |> Option.map ~f:Model.of_tuple)

  let upsert connection ~state =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.exec
        Caqti_type.(tup3 string int bool)
        {sql|
INSERT INTO core_migration_state (
  namespace,
  version,
  dirty
) VALUES (
  ?,
  ?,
  ?
) ON DUPLICATE KEY UPDATE
version = VALUES(version),
dirty = VALUES(dirty)
|sql}
    in
    Connection.exec request (Model.to_tuple state)
end

module RepoPostgreSql = struct
  let create_table_if_not_exists connection =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.exec Caqti_type.unit
        {sql|
CREATE TABLE IF NOT EXISTS core_migration_state (
  namespace VARCHAR(128) NOT NULL PRIMARY KEY,
  version INTEGER,
  dirty BOOL NOT NULL
);
 |sql}
    in
    Connection.exec request ()

  let get connection ~namespace =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.find_opt Caqti_type.string
        Caqti_type.(tup3 string int bool)
        {sql|
SELECT
  namespace,
  version,
  dirty
FROM core_migration_state
WHERE namespace = ?;
|sql}
    in
    let* result = Connection.find_opt request namespace in
    Lwt.return @@ Ok (result |> Option.map ~f:Model.of_tuple)

  let upsert connection ~state =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.exec
        Caqti_type.(tup3 string int bool)
        {sql|
INSERT INTO core_migration_state (
  namespace,
  version,
  dirty
) VALUES (
  ?,
  ?,
  ?
) ON CONFLICT (namespace)
DO UPDATE SET version = EXCLUDED.version,
dirty = EXCLUDED.dirty
|sql}
    in
    Connection.exec request (Model.to_tuple state)
end

module PostgreSql = Make (RepoPostgreSql)

let postgresql =
  Core.Container.create_binding key (module PostgreSql) (module PostgreSql)

module MariaDb = Make (RepoMariaDb)

let mariadb = Core.Container.create_binding key (module MariaDb) (module MariaDb)
