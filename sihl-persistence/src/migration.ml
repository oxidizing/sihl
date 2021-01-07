let log_src = Logs.Src.create ("sihl.service." ^ Sihl_contract.Migration.name)

module Logs = (val Logs.src_log log_src : Logs.LOG)
module Map = Map.Make (String)

let registered_migrations : Sihl_contract.Migration.t Map.t ref = ref Map.empty

module Make (Repo : Migration_repo.Sig) : Sihl_contract.Migration.Sig = struct
  let setup () =
    Logs.debug (fun m -> m "Setting up table if not exists");
    Repo.create_table_if_not_exists ()
  ;;

  let has ~namespace = Repo.get ~namespace |> Lwt.map Option.is_some

  let get ~namespace =
    let open Lwt.Syntax in
    let* state = Repo.get ~namespace in
    Lwt.return
    @@
    match state with
    | Some state -> state
    | None ->
      raise
        (Sihl_contract.Migration.Exception
           (Printf.sprintf "Could not get migration state for %s" namespace))
  ;;

  let upsert state = Repo.upsert ~state

  let mark_dirty ~namespace =
    let open Lwt.Syntax in
    let* state = get ~namespace in
    let dirty_state = Repo.Migration.mark_dirty state in
    let* () = upsert dirty_state in
    Lwt.return dirty_state
  ;;

  let mark_clean ~namespace =
    let open Lwt.Syntax in
    let* state = get ~namespace in
    let clean_state = Repo.Migration.mark_clean state in
    let* () = upsert clean_state in
    Lwt.return clean_state
  ;;

  let increment ~namespace =
    let open Lwt.Syntax in
    let* state = get ~namespace in
    let updated_state = Repo.Migration.increment state in
    let* () = upsert updated_state in
    Lwt.return updated_state
  ;;

  let register_migration migration =
    let label, _ = migration in
    let found = Map.find_opt label !registered_migrations in
    match found with
    | Some _ ->
      Logs.debug (fun m ->
          m "Found duplicate migration '%s', ignoring it" label)
    | None ->
      registered_migrations := Map.add label migration !registered_migrations
  ;;

  let register_migrations migrations = List.iter register_migration migrations

  let set_fk_check_request =
    Caqti_request.exec Caqti_type.bool "SET FOREIGN_KEY_CHECKS = ?;"
  ;;

  let with_disabled_fk_check f =
    let open Lwt.Syntax in
    Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        let* () =
          Connection.exec set_fk_check_request false
          |> Lwt.map Database.raise_error
        in
        Lwt.finalize
          (fun () -> f connection)
          (fun () ->
            Connection.exec set_fk_check_request true
            |> Lwt.map Database.raise_error))
  ;;

  let execute_steps migration =
    let open Lwt.Syntax in
    let namespace, steps = migration in
    let rec run steps =
      match steps with
      | [] -> Lwt.return ()
      | Sihl_contract.Migration.{ label; statement; check_fk = true } :: steps
        ->
        Logs.debug (fun m -> m "Running %s" label);
        let query (module Connection : Caqti_lwt.CONNECTION) =
          let req =
            Caqti_request.exec ~oneshot:true Caqti_type.unit statement
          in
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
                let req =
                  Caqti_request.exec ~oneshot:true Caqti_type.unit statement
                in
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
    let open Lwt.Syntax in
    let namespace, _ = migration in
    let* () = setup () in
    let* has_state = has ~namespace in
    let* state =
      if has_state
      then
        let* state = get ~namespace in
        if Repo.Migration.dirty state
        then (
          Logs.err (fun m ->
              m
                "Dirty migration found for %s, this has to be fixed manually"
                namespace);
          Logs.info (fun m ->
              m
                "Set the column 'dirty' from 1/true to 0/false after you have \
                 fixed the database state.");
          raise Sihl_contract.Migration.Dirty_migration)
        else mark_dirty ~namespace
      else (
        Logs.debug (fun m -> m "Setting up table for %s" namespace);
        let state = Repo.Migration.create ~namespace in
        let* () = upsert state in
        Lwt.return state)
    in
    let migration_to_apply = Repo.Migration.steps_to_apply migration state in
    let n_migrations = List.length (snd migration_to_apply) in
    if n_migrations > 0
    then
      Logs.info (fun m ->
          m
            "Executing %d migrations for '%s'..."
            (List.length (snd migration_to_apply))
            namespace)
    else Logs.info (fun m -> m "No migrations to execute for '%s'" namespace);
    let* () =
      Lwt.catch
        (fun () -> execute_steps migration_to_apply)
        (fun exn ->
          let err = Printexc.to_string exn in
          Logs.err (fun m ->
              m
                "Error while running migration '%a': %s"
                Sihl_facade.Migration.pp
                migration
                err);
          raise (Sihl_contract.Migration.Exception err))
    in
    let* _ = mark_clean ~namespace in
    Lwt.return ()
  ;;

  let execute migrations =
    let open Lwt.Syntax in
    let n = List.length migrations in
    if n > 0
    then
      Logs.info (fun m -> m "Looking at %i migrations" (List.length migrations))
    else Logs.info (fun m -> m "No migrations to execute");
    let rec run migrations =
      match migrations with
      | [] -> Lwt.return ()
      | migration :: migrations ->
        let* () = execute_migration migration in
        run migrations
    in
    run migrations
  ;;

  let run_all () =
    let steps =
      !registered_migrations |> Map.to_seq |> List.of_seq |> List.map snd
    in
    execute steps
  ;;

  let migrate_cmd =
    Sihl_core.Command.make
      ~name:"migrate"
      ~description:"Run all migrations"
      (fun _ -> run_all ())
  ;;

  let start () = run_all ()
  let stop () = Lwt.return ()

  let lifecycle =
    Sihl_core.Container.Lifecycle.create
      Sihl_contract.Migration.name
      ~dependencies:(fun () -> [ Database.lifecycle ])
      ~start
      ~stop
  ;;

  let register ?(migrations = []) () =
    register_migrations migrations;
    Sihl_core.Container.Service.create ~commands:[ migrate_cmd ] lifecycle
  ;;
end

module PostgreSql = Make (Migration_repo.PostgreSql)
module MariaDb = Make (Migration_repo.MariaDb)
