open Lwt.Syntax
module Core = Sihl_core
module Migration = Sihl_type.Migration
module Migration_state = Sihl_type.Migration_state

let log_src = Logs.Src.create "sihl.service.migration"

module Logs = (val Logs.src_log log_src : Logs.LOG)
module Map = Map.Make (String)

let registered_migrations : Migration.steps Map.t ref = ref Map.empty

let register_migration migration =
  let label, _ = migration in
  let found = Map.find_opt label !registered_migrations in
  match found with
  | Some _ -> Logs.debug (fun m -> m "Found duplicate migration '%s', ignoring it" label)
  | None -> registered_migrations := Map.add label (snd migration) !registered_migrations
;;

let register_migrations migrations = List.iter register_migration migrations

module Make (MigrationRepo : Migration_repo.Sig) : Sihl_contract.Migration.Sig = struct
  let setup () =
    Logs.debug (fun m -> m "Setting up table if not exists");
    MigrationRepo.create_table_if_not_exists ()
  ;;

  let has ~namespace = MigrationRepo.get ~namespace |> Lwt.map Option.is_some

  let get ~namespace =
    let* state = MigrationRepo.get ~namespace in
    Lwt.return
    @@
    match state with
    | Some state -> state
    | None ->
      raise
        (Sihl_contract.Migration.Exception
           (Printf.sprintf "Could not get migration state for %s" namespace))
  ;;

  let upsert state = MigrationRepo.upsert ~state

  let mark_dirty ~namespace =
    let* state = get ~namespace in
    let dirty_state = Migration_state.mark_dirty state in
    let* () = upsert dirty_state in
    Lwt.return dirty_state
  ;;

  let mark_clean ~namespace =
    let* state = get ~namespace in
    let clean_state = Migration_state.mark_clean state in
    let* () = upsert clean_state in
    Lwt.return clean_state
  ;;

  let increment ~namespace =
    let* state = get ~namespace in
    let updated_state = Migration_state.increment state in
    let* () = upsert updated_state in
    Lwt.return updated_state
  ;;

  let register_migration migration = register_migration migration |> ignore
  let register_migrations migrations = register_migrations migrations |> ignore

  let set_fk_check_request =
    Caqti_request.exec Caqti_type.bool "SET FOREIGN_KEY_CHECKS = ?;"
  ;;

  let with_disabled_fk_check f =
    Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        let* () =
          Connection.exec set_fk_check_request false |> Lwt.map Database.raise_error
        in
        Lwt.finalize
          (fun () -> f connection)
          (fun () ->
            Connection.exec set_fk_check_request true |> Lwt.map Database.raise_error))
  ;;

  let execute_steps migration =
    let namespace, steps = migration in
    let rec run steps =
      match steps with
      | [] -> Lwt.return ()
      | Migration.{ label; statement; check_fk = true } :: steps ->
        Logs.debug (fun m -> m "Running %s" label);
        let query (module Connection : Caqti_lwt.CONNECTION) =
          let req = Caqti_request.exec ~oneshot:true Caqti_type.unit statement in
          Connection.exec req () |> Lwt.map Database.raise_error
        in
        let* () = Database.query query in
        Logs.debug (fun m -> m "Ran %s" label);
        let* _ = increment ~namespace in
        run steps
      | { label; statement; check_fk = false } :: steps ->
        let* () =
          with_disabled_fk_check (fun connection ->
              Logs.debug (fun m -> m "Running %s without fk checks" label);
              let query (module Connection : Caqti_lwt.CONNECTION) =
                let req = Caqti_request.exec ~oneshot:true Caqti_type.unit statement in
                Connection.exec req () |> Lwt.map Database.raise_error
              in
              query connection)
        in
        Logs.debug (fun m -> m "Ran %s" label);
        let* _ = increment ~namespace in
        run steps
    in
    let () =
      match List.length steps with
      | 0 -> Logs.debug (fun m -> m "No migrations to apply for %s" namespace)
      | n -> Logs.debug (fun m -> m "Applying %i migrations for %s" n namespace)
    in
    run steps
  ;;

  let execute_migration migration =
    let namespace, _ = migration in
    Logs.debug (fun m -> m "Execute migrations for %s" namespace);
    let* () = setup () in
    let* has_state = has ~namespace in
    let* state =
      if has_state
      then
        let* state = get ~namespace in
        if Migration_state.dirty state
        then (
          let msg =
            Printf.sprintf
              "Dirty migration found for %s, has to be fixed manually"
              namespace
          in
          Logs.err (fun m -> m "%s" msg);
          raise (Sihl_contract.Migration.Exception msg))
        else mark_dirty ~namespace
      else (
        Logs.debug (fun m -> m "Setting up table for %s" namespace);
        let state = Migration_state.create ~namespace in
        let* () = upsert state in
        Lwt.return state)
    in
    let migration_to_apply = Migration_state.steps_to_apply migration state in
    let* () = execute_steps migration_to_apply in
    let* _ = mark_clean ~namespace in
    Lwt.return @@ Ok ()
  ;;

  (* let progress_bar cur goal =
   *   let scale = 0.7 in
   *   let width = Terminal_size.get_columns () in
   *   match width with
   *   | None -> ()
   *   | Some width ->
   *     (\* TOOD [aerben] maybe print newline after cur == goal *\)
   *     let progress = Float.div cur goal in
   *     let bar_width = Float.mul scale (Int.to_float width) in
   *     let markers = Float.to_int @@ Float.round @@ Float.mul bar_width progress in
   *     let percentage = Float.to_int @@ Float.round @@ Float.mul 100.0 progress in
   *     let bar =
   *       Printf.sprintf
   *         "|%s%s| (%s)\r"
   *         (String.make markers '#')
   *         (String.make (Float.to_int bar_width - markers) '-')
   *         (Int.to_string percentage)
   *     in
   *     print_string bar
   * ;; *)

  let execute migrations =
    let n = List.length migrations in
    if n > 0
    then Logs.debug (fun m -> m "Executing %i migrations" (List.length migrations))
    else Logs.debug (fun m -> m "No migrations to execute");
    let open Lwt in
    let rec run migrations =
      match migrations with
      | [] -> Lwt.return ()
      | migration :: migrations ->
        execute_migration migration
        >>= (function
        | Ok () -> run migrations
        | Error err ->
          Logs.err (fun m ->
              m "Error while running migration %a: %s" Migration.pp migration err);
          raise (Sihl_contract.Migration.Exception err))
    in
    run migrations
  ;;

  let run_all () =
    let steps = !registered_migrations |> Map.to_seq |> List.of_seq in
    execute steps
  ;;

  let migrate_cmd =
    Core.Command.make ~name:"migrate" ~description:"Run all migrations" (fun _ ->
        run_all ())
  ;;

  let check_migrations_status () =
    let* migrations = MigrationRepo.get_all () in
    let unapplied =
      Sihl_type.Migration.get_migrations_status migrations !registered_migrations
    in
    List.iter
      (fun (namespace, count) ->
        match count with
        | None ->
          Logs.warn (fun m ->
              m
                "Could not find registered migrations for namespace '%s'. This implies \
                 you removed all migrations of that namespace. Migrations should be \
                 append-only. If you intended to remove those migrations, make sure to \
                 remove the migration state in your database/other persistence layer."
                namespace)
        | Some count ->
          if count > 0
          then
            Logs.info (fun m ->
                m
                  "Unapplied migrations for namespace '%s' detected. Found %s unapplied \
                   migrations, run command 'migrate'."
                  namespace
                  (Int.to_string count))
          else if count < 0
          then
            Logs.warn (fun m ->
                m
                  "Fewer registered migrations found than migration state indicates for \
                   namespace '%s'. Current migration state version is ahead of \
                   registered migrations by %s. This implies you removed migrations, \
                   which should be append-only."
                  namespace
                  (Int.to_string @@ Int.abs count))
          else ())
      unapplied;
    Lwt.return ()
  ;;

  let start () =
    if Sihl_core.Configuration.is_test ()
    then Lwt.return ()
    else check_migrations_status ()
  ;;

  let stop _ = Lwt.return ()

  let lifecycle =
    Core.Container.Lifecycle.create
      "migration"
      ~dependencies:[ Database.lifecycle ]
      ~start
      ~stop
  ;;

  let register ?(migrations = []) () =
    register_migrations migrations;
    Core.Container.Service.create ~commands:[ migrate_cmd ] lifecycle
  ;;
end
