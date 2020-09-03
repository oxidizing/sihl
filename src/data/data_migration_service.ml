open Base
open Lwt.Syntax
module Model = Data_migration_core

module Make
    (Log : Log.Sig.SERVICE)
    (CmdService : Cmd.Sig.SERVICE)
    (Db : Data_db_sig.SERVICE)
    (MigrationRepo : Data_migration_sig.REPO) : Data_migration_sig.SERVICE =
struct
  let setup ctx =
    Log.debug (fun m -> m "MIGRATION: Setting up table if not exists");
    MigrationRepo.create_table_if_not_exists ctx

  let has ctx ~namespace =
    MigrationRepo.get ctx ~namespace |> Lwt.map Option.is_some

  let get ctx ~namespace =
    let* state = MigrationRepo.get ctx ~namespace in
    Lwt.return
    @@
    match state with
    | Some state -> state
    | None ->
        raise
          (Data_migration_core.Exception
             (Printf.sprintf "MIGRATION: Could not get migration state for %s"
                namespace))

  let upsert ctx state = MigrationRepo.upsert ctx ~state

  let mark_dirty ctx ~namespace =
    let* state = get ctx ~namespace in
    let dirty_state = Model.mark_dirty state in
    let* () = upsert ctx dirty_state in
    Lwt.return dirty_state

  let mark_clean ctx ~namespace =
    let* state = get ctx ~namespace in
    let clean_state = Model.mark_clean state in
    let* () = upsert ctx clean_state in
    Lwt.return clean_state

  let increment ctx ~namespace =
    let* state = get ctx ~namespace in
    let updated_state = Model.increment state in
    let* () = upsert ctx updated_state in
    Lwt.return updated_state

  let register migration =
    Data_migration_core.Registry.register migration |> ignore

  let get_migrations _ = Lwt.return (Data_migration_core.Registry.get_all ())

  let execute_steps ctx migration =
    let namespace, steps = migration in
    let rec run steps =
      match steps with
      | [] -> Lwt.return ()
      | Model.Migration.{ label; statement; check_fk = true } :: steps ->
          Log.debug (fun m -> m "MIGRATION: Running %s" label);
          let query (module Connection : Caqti_lwt.CONNECTION) =
            let req =
              Caqti_request.exec ~oneshot:true Caqti_type.unit statement
            in
            Connection.exec req ()
          in
          let* () = Db.query ctx query in
          Log.debug (fun m -> m "MIGRATION: Ran %s" label);
          let* _ = increment ctx ~namespace in
          run steps
      | { label; statement; check_fk = false } :: steps ->
          let* () =
            Db.with_disabled_fk_check ctx (fun ctx ->
                Log.debug (fun m ->
                    m "MIGRATION: Running %s without fk checks" label);
                let query (module Connection : Caqti_lwt.CONNECTION) =
                  let req =
                    Caqti_request.exec ~oneshot:true Caqti_type.unit statement
                  in
                  Connection.exec req ()
                in
                Db.query ctx query)
          in
          Log.debug (fun m -> m "MIGRATION: Ran %s" label);
          let* _ = increment ctx ~namespace in
          run steps
    in
    let () =
      match List.length steps with
      | 0 ->
          Log.debug (fun m ->
              m "MIGRATION: No migrations to apply for %s" namespace)
      | n ->
          Log.debug (fun m ->
              m "MIGRATION: Applying %i migrations for %s" n namespace)
    in
    run steps

  let execute_migration ctx migration =
    let namespace, _ = migration in
    Log.debug (fun m -> m "MIGRATION: Execute migrations for %s" namespace);
    let* () = setup ctx in
    let* has_state = has ctx ~namespace in
    let* state =
      if has_state then
        let* state = get ctx ~namespace in
        if Model.dirty state then (
          let msg =
            Printf.sprintf
              "Dirty migration found for %s, has to be fixed manually" namespace
          in
          Log.err (fun m -> m "MIGRATION: %s" msg);
          raise (Data_migration_core.Exception msg) )
        else mark_dirty ctx ~namespace
      else (
        Log.debug (fun m -> m "MIGRATION: Setting up table for %s" namespace);
        let state = Model.create ~namespace in
        let* () = upsert ctx state in
        Lwt.return state )
    in
    let migration_to_apply = Model.steps_to_apply migration state in
    let* () = execute_steps ctx migration_to_apply in
    let* _ = mark_clean ctx ~namespace in
    Lwt.return @@ Ok ()

  let execute ctx migrations =
    let n = List.length migrations in
    if n > 0 then
      Log.debug (fun m ->
          m "MIGRATION: Executing %i migrations" (List.length migrations))
    else Log.debug (fun m -> m "MIGRATION: No migrations to execute");
    let open Lwt in
    let rec run migrations ctx =
      match migrations with
      | [] -> Lwt.return ()
      | migration :: migrations -> (
          execute_migration ctx migration >>= function
          | Ok () -> run migrations ctx
          | Error err ->
              Log.err (fun m ->
                  m "MIGRATION: Error while running migration %a: %s"
                    Model.Migration.pp migration err);
              raise (Model.Exception err) )
    in
    run migrations ctx

  let run_all ctx =
    let* migrations = get_migrations ctx in
    execute ctx migrations

  let migrate_cmd =
    Cmd.make ~name:"migrate" ~description:"Run all migrations"
      ~fn:(fun _ ->
        let ctx = Core.Ctx.empty |> Db.add_pool in
        run_all ctx)
      ()

  let lifecycle =
    Core.Container.Lifecycle.make "migration"
      ~dependencies:[ CmdService.lifecycle; Db.lifecycle; Log.lifecycle ]
      (fun ctx ->
        CmdService.register_command migrate_cmd;
        Lwt.return ctx)
      (fun _ -> Lwt.return ())
end

module Repo = struct
  module MakeMariaDb (Db : Data_db_sig.SERVICE) : Data_migration_sig.REPO =
  struct
    let create_request =
      Caqti_request.exec Caqti_type.unit
        {sql|
CREATE TABLE IF NOT EXISTS core_migration_state (
  namespace VARCHAR(128) NOT NULL,
  version INTEGER,
  dirty BOOL NOT NULL,
  PRIMARY KEY (namespace)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
 |sql}

    let create_table_if_not_exists ctx =
      Db.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec create_request ())

    let get_request =
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

    let get ctx ~namespace =
      Db.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.find_opt get_request namespace)
      |> Lwt.map (Option.map ~f:Model.of_tuple)

    let upsert_request =
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

    let upsert ctx ~state =
      Db.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec upsert_request (Model.to_tuple state))
  end

  module MakePostgreSql (Db : Data_db_sig.SERVICE) : Data_migration_sig.REPO =
  struct
    let create_request =
      Caqti_request.exec Caqti_type.unit
        {sql|
CREATE TABLE IF NOT EXISTS core_migration_state (
  namespace VARCHAR(128) NOT NULL PRIMARY KEY,
  version INTEGER,
  dirty BOOL NOT NULL
);
 |sql}

    let create_table_if_not_exists ctx =
      Db.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec create_request ())

    let get_request =
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

    let get ctx ~namespace =
      Db.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.find_opt get_request namespace)
      |> Lwt.map (Option.map ~f:Model.of_tuple)

    let upsert_request =
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

    let upsert ctx ~state =
      Db.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec upsert_request (Model.to_tuple state))
  end
end
