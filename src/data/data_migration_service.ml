open Base
module Model = Data_migration_core

let ( let* ) = Lwt_result.bind

module Make
    (CmdService : Cmd.Sig.SERVICE)
    (Db : Data_db_sig.SERVICE)
    (MigrationRepo : Data_migration_sig.REPO) : Data_migration_sig.SERVICE =
struct
  let setup ctx =
    Logs.debug (fun m -> m "MIGRATION: Setting up table if not exists");
    MigrationRepo.create_table_if_not_exists |> Db.query ctx

  let has ctx ~namespace =
    let* result = MigrationRepo.get ~namespace |> Db.query ctx in
    Lwt_result.return (Option.is_some result)

  let get ctx ~namespace =
    let* state = MigrationRepo.get ~namespace |> Db.query ctx in
    Lwt.return
    @@
    match state with
    | Some state -> Ok state
    | None ->
        Error
          (Printf.sprintf "MIGRATION: Could not get migration state for %s"
             namespace)

  let upsert ctx state = MigrationRepo.upsert ~state |> Db.query ctx

  let mark_dirty ctx ~namespace =
    let* state = get ctx ~namespace in
    let dirty_state = Model.mark_dirty state in
    let* () = upsert ctx dirty_state in
    Lwt.return @@ Ok dirty_state

  let mark_clean ctx ~namespace =
    let* state = get ctx ~namespace in
    let clean_state = Model.mark_clean state in
    let* () = upsert ctx clean_state in
    Lwt.return @@ Ok clean_state

  let increment ctx ~namespace =
    let* state = get ctx ~namespace in
    let updated_state = Model.increment state in
    let* () = upsert ctx updated_state in
    Lwt.return @@ Ok updated_state

  let register _ migration =
    Data_migration_core.Registry.register migration;
    Lwt.return @@ Ok ()

  let get_migrations _ =
    Lwt.return @@ Ok (Data_migration_core.Registry.get_all ())

  let execute_steps ctx migration =
    let open Lwt in
    let namespace, steps = migration in
    let rec run steps =
      match steps with
      | [] -> Lwt_result.return ()
      | Model.Migration.{ label; statement; check_fk = true } :: steps -> (
          Logs.debug (fun m -> m "MIGRATION: Running %s" label);
          let query (module Connection : Caqti_lwt.CONNECTION) =
            let req =
              Caqti_request.exec ~oneshot:true Caqti_type.unit statement
            in
            Connection.exec req () |> Lwt_result.map_err Caqti_error.show
          in
          Db.query ctx query >>= function
          | Ok () ->
              Logs.debug (fun m -> m "MIGRATION: Ran %s" label);
              let* _ = increment ctx ~namespace in
              run steps
          | Error err ->
              let msg =
                Printf.sprintf
                  "MIGRATION: Error while running migration for %s %s" namespace
                  err
              in
              Logs.err (fun m -> m "%s" msg);
              Lwt.return @@ Error msg )
      | { label; statement; check_fk = false } :: steps -> (
          let* _ = Db.set_fk_check ~check:false |> Db.query ctx in
          Logs.debug (fun m ->
              m "MIGRATION: Running %s without fk checks" label);
          let query (module Connection : Caqti_lwt.CONNECTION) =
            let req =
              Caqti_request.exec ~oneshot:true Caqti_type.unit statement
            in
            Connection.exec req () |> Lwt_result.map_err Caqti_error.show
          in
          Db.query ctx query >>= function
          | Ok () ->
              let* _ = Db.set_fk_check ~check:true |> Db.query ctx in
              Logs.debug (fun m -> m "MIGRATION: Ran %s" label);
              let* _ = increment ctx ~namespace in
              run steps
          | Error err ->
              let* _ = Db.set_fk_check ~check:true |> Db.query ctx in
              let msg =
                Printf.sprintf
                  "MIGRATION: Error while running migration for %s %s" namespace
                  err
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
    run steps

  let execute_migration ctx migration =
    let namespace, _ = migration in
    Logs.debug (fun m -> m "MIGRATION: Execute migrations for %s" namespace);
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
          Logs.err (fun m -> m "MIGRATION: %s" msg);
          Lwt_result.fail msg )
        else mark_dirty ctx ~namespace
      else (
        Logs.debug (fun m -> m "MIGRATION: Setting up table for %s" namespace);
        let state = Model.create ~namespace in
        let* () = upsert ctx state in
        Lwt.return @@ Ok state )
    in
    let migration_to_apply = Model.steps_to_apply migration state in
    let* result =
      Db.single_connection ctx (fun ctx -> execute_steps ctx migration_to_apply)
    in
    let* () = Lwt.return result in
    let* _ = mark_clean ctx ~namespace in
    Lwt.return @@ Ok ()

  let execute ctx migrations =
    let n = List.length migrations in
    if n > 0 then
      Logs.debug (fun m ->
          m "MIGRATION: Executing %i migrations" (List.length migrations))
    else Logs.debug (fun m -> m "MIGRATION: No migrations to execute");
    let open Lwt in
    let rec run migrations ctx =
      match migrations with
      | [] -> Lwt_result.return ()
      | migration :: migrations -> (
          execute_migration ctx migration >>= function
          | Ok () -> run migrations ctx
          | Error err -> return (Error err) )
    in
    run migrations ctx

  let run_all ctx = Lwt_result.bind (get_migrations ctx) (execute ctx)

  let migrate_cmd =
    Cmd.make ~name:"migrate" ~description:"Run all migrations"
      ~fn:(fun _ ->
        let ctx = Core.Ctx.empty |> Db.add_pool in
        run_all ctx)
      ()

  let lifecycle =
    Core.Container.Lifecycle.make "migration"
      ~dependencies:[ CmdService.lifecycle; Db.lifecycle ]
      (fun ctx ->
        CmdService.register_command ctx migrate_cmd
        |> Lwt.map Result.ok_or_failwith
        |> Lwt.map (fun () -> ctx))
      (fun _ -> Lwt.return ())
end

module Repo = struct
  module MariaDb = struct
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

    let create_table_if_not_exists connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      Connection.exec create_request () |> Lwt_result.map_err Caqti_error.show

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

    let get connection ~namespace =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let* result =
        Connection.find_opt get_request namespace
        |> Lwt_result.map_err Caqti_error.show
      in
      Lwt.return @@ Ok (result |> Option.map ~f:Model.of_tuple)

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

    let upsert connection ~state =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      Connection.exec upsert_request (Model.to_tuple state)
      |> Lwt_result.map_err Caqti_error.show
  end

  module PostgreSql = struct
    let create_request =
      Caqti_request.exec Caqti_type.unit
        {sql|
CREATE TABLE IF NOT EXISTS core_migration_state (
  namespace VARCHAR(128) NOT NULL PRIMARY KEY,
  version INTEGER,
  dirty BOOL NOT NULL
);
 |sql}

    let create_table_if_not_exists connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      Connection.exec create_request () |> Lwt_result.map_err Caqti_error.show

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

    let get connection ~namespace =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let* result =
        Connection.find_opt get_request namespace
        |> Lwt_result.map_err Caqti_error.show
      in
      Lwt.return @@ Ok (result |> Option.map ~f:Model.of_tuple)

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

    let upsert connection ~state =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      Connection.exec upsert_request (Model.to_tuple state)
      |> Lwt_result.map_err Caqti_error.show
  end
end
