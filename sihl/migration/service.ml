open Lwt.Syntax
module Core = Sihl_core
module Database = Sihl_database

let log_src = Logs.Src.create "sihl.service.migration"

module Logs = (val Logs.src_log log_src : Logs.LOG)

let registred_migrations : Model.Migration.t list ref = ref []

let register_migration migration =
  registred_migrations := List.concat [ !registred_migrations; [ migration ] ]
;;

let register_migrations migrations =
  registred_migrations := List.concat [ !registred_migrations; migrations ]
;;

module Make (MigrationRepo : Sig.REPO) : Sig.SERVICE = struct
  let setup ctx =
    Logs.debug (fun m -> m "Setting up table if not exists");
    MigrationRepo.create_table_if_not_exists ctx
  ;;

  let has ctx ~namespace = MigrationRepo.get ctx ~namespace |> Lwt.map Option.is_some

  let get ctx ~namespace =
    let* state = MigrationRepo.get ctx ~namespace in
    Lwt.return
    @@
    match state with
    | Some state -> state
    | None ->
      raise
        (Model.Exception (Printf.sprintf "Could not get migration state for %s" namespace))
  ;;

  let upsert ctx state = MigrationRepo.upsert ctx ~state

  let mark_dirty ctx ~namespace =
    let* state = get ctx ~namespace in
    let dirty_state = Model.mark_dirty state in
    let* () = upsert ctx dirty_state in
    Lwt.return dirty_state
  ;;

  let mark_clean ctx ~namespace =
    let* state = get ctx ~namespace in
    let clean_state = Model.mark_clean state in
    let* () = upsert ctx clean_state in
    Lwt.return clean_state
  ;;

  let increment ctx ~namespace =
    let* state = get ctx ~namespace in
    let updated_state = Model.increment state in
    let* () = upsert ctx updated_state in
    Lwt.return updated_state
  ;;

  let register_migration migration = register_migration migration |> ignore
  let register_migrations migrations = register_migrations migrations |> ignore
  let get_migrations _ = Lwt.return !registred_migrations

  let set_fk_check_request =
    Caqti_request.exec Caqti_type.bool "SET FOREIGN_KEY_CHECKS = ?;"
  ;;

  let with_disabled_fk_check ctx f =
    Database.Service.query ctx (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        let* () = Connection.exec set_fk_check_request false |> Lwt.map Result.get_ok in
        Lwt.finalize
          (fun () -> f connection)
          (fun () -> Connection.exec set_fk_check_request true |> Lwt.map Result.get_ok))
  ;;

  let execute_steps ctx migration =
    let namespace, steps = migration in
    let rec run steps =
      match steps with
      | [] -> Lwt.return ()
      | Model.Migration.{ label; statement; check_fk = true } :: steps ->
        Logs.debug (fun m -> m "Running %s" label);
        let query (module Connection : Caqti_lwt.CONNECTION) =
          let req = Caqti_request.exec ~oneshot:true Caqti_type.unit statement in
          Connection.exec req () |> Lwt.map Result.get_ok
        in
        let* () = Database.Service.query ctx query in
        Logs.debug (fun m -> m "Ran %s" label);
        let* _ = increment ctx ~namespace in
        run steps
      | { label; statement; check_fk = false } :: steps ->
        let* () =
          with_disabled_fk_check ctx (fun connection ->
              Logs.debug (fun m -> m "Running %s without fk checks" label);
              let query (module Connection : Caqti_lwt.CONNECTION) =
                let req = Caqti_request.exec ~oneshot:true Caqti_type.unit statement in
                Connection.exec req () |> Lwt.map Result.get_ok
              in
              query connection)
        in
        Logs.debug (fun m -> m "Ran %s" label);
        let* _ = increment ctx ~namespace in
        run steps
    in
    let () =
      match List.length steps with
      | 0 -> Logs.debug (fun m -> m "No migrations to apply for %s" namespace)
      | n -> Logs.debug (fun m -> m "Applying %i migrations for %s" n namespace)
    in
    run steps
  ;;

  let execute_migration ctx migration =
    let namespace, _ = migration in
    Logs.debug (fun m -> m "Execute migrations for %s" namespace);
    let* () = setup ctx in
    let* has_state = has ctx ~namespace in
    let* state =
      if has_state
      then
        let* state = get ctx ~namespace in
        if Model.dirty state
        then (
          let msg =
            Printf.sprintf
              "Dirty migration found for %s, has to be fixed manually"
              namespace
          in
          Logs.err (fun m -> m "%s" msg);
          raise (Model.Exception msg))
        else mark_dirty ctx ~namespace
      else (
        Logs.debug (fun m -> m "Setting up table for %s" namespace);
        let state = Model.create ~namespace in
        let* () = upsert ctx state in
        Lwt.return state)
    in
    let migration_to_apply = Model.steps_to_apply migration state in
    let* () = execute_steps ctx migration_to_apply in
    let* _ = mark_clean ctx ~namespace in
    Lwt.return @@ Ok ()
  ;;

  let execute ctx migrations =
    let n = List.length migrations in
    if n > 0
    then Logs.debug (fun m -> m "Executing %i migrations" (List.length migrations))
    else Logs.debug (fun m -> m "No migrations to execute");
    let open Lwt in
    let rec run migrations ctx =
      match migrations with
      | [] -> Lwt.return ()
      | migration :: migrations ->
        execute_migration ctx migration
        >>= (function
        | Ok () -> run migrations ctx
        | Error err ->
          Logs.err (fun m ->
              m "Error while running migration %a: %s" Model.Migration.pp migration err);
          raise (Model.Exception err))
    in
    run migrations ctx
  ;;

  let run_all ctx =
    let* migrations = get_migrations ctx in
    execute ctx migrations
  ;;

  let migrate_cmd =
    Core.Command.make ~name:"migrate" ~description:"Run all migrations" (fun _ ->
        let ctx = Core.Ctx.create () in
        run_all ctx)
  ;;

  let start ctx = Lwt.return ctx
  let stop _ = Lwt.return ()

  let lifecycle =
    Core.Container.Lifecycle.create
      "migration"
      ~dependencies:[ Database.Service.lifecycle ]
      ~start
      ~stop
  ;;

  let register ?(migrations = []) () =
    register_migrations migrations;
    Core.Container.Service.create ~commands:[ migrate_cmd ] lifecycle
  ;;
end

module Repo = Repo
