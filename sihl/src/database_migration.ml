include Contract_migration

let log_src = Logs.Src.create ("sihl.service." ^ Contract_migration.name)

module Logs = (val Logs.src_log log_src : Logs.LOG)
module Map = Map.Make (String)

let registered_migrations = ref []

module Make (Repo : Database_migration_repo.Sig) : Contract_migration.Sig =
struct
  type config = { migration_state_table : string option }

  let config migration_state_table = { migration_state_table }

  let schema =
    let open Conformist in
    make
      [ optional
          (string ~default:"core_migration_state" "MIGRATION_STATE_TABLE")
      ]
      config
  ;;

  let table () =
    Option.value
      ~default:"core_migration_state"
      (Core_configuration.read schema).migration_state_table
  ;;

  let setup ?ctx () =
    Logs.debug (fun m -> m "Setting up table if not exists");
    Repo.create_table_if_not_exists ?ctx (table ())
  ;;

  let has ?ctx namespace =
    Repo.get ?ctx (table ()) ~namespace |> Lwt.map Option.is_some
  ;;

  let get ?ctx namespace =
    let%lwt state = Repo.get ?ctx (table ()) ~namespace in
    Lwt.return
    @@
    match state with
    | Some state -> state
    | None ->
      raise
        (Contract_migration.Exception
           (Printf.sprintf "Could not get migration state for %s" namespace))
  ;;

  let upsert ?ctx state = Repo.upsert ?ctx (table ()) state

  let mark_dirty ?ctx namespace =
    let%lwt state = get ?ctx namespace in
    let dirty_state = Repo.Migration.mark_dirty state in
    let%lwt () = upsert ?ctx dirty_state in
    Lwt.return dirty_state
  ;;

  let mark_clean ?ctx namespace =
    let%lwt state = get ?ctx namespace in
    let clean_state = Repo.Migration.mark_clean state in
    let%lwt () = upsert ?ctx clean_state in
    Lwt.return clean_state
  ;;

  let increment ?ctx namespace =
    let%lwt state = get ?ctx namespace in
    let updated_state = Repo.Migration.increment state in
    let%lwt () = upsert ?ctx updated_state in
    Lwt.return updated_state
  ;;

  let register_migration migration =
    let label, _ = migration in
    let found = List.assoc_opt label !registered_migrations in
    match found with
    | Some _ ->
      Logs.debug (fun m ->
        m "Found duplicate migration '%s', ignoring it" label)
    | None -> registered_migrations := !registered_migrations @ [ migration ]
  ;;

  let register_migrations migrations = List.iter register_migration migrations

  let set_fk_check_request =
    let open Caqti_request.Infix in
    "SET FOREIGN_KEY_CHECKS = ?" |> Caqti_type.(bool ->. unit)
  ;;

  let with_disabled_fk_check ?ctx f =
    Database.query ?ctx (fun connection ->
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let%lwt () =
        Connection.exec set_fk_check_request false
        |> Lwt.map Database.raise_error
      in
      Lwt.finalize
        (fun () -> f connection)
        (fun () ->
          Connection.exec set_fk_check_request true
          |> Lwt.map Database.raise_error))
  ;;

  let execute_steps ?ctx migration =
    let open Caqti_request.Infix in
    let namespace, steps = migration in
    let rec run steps =
      match steps with
      | [] -> Lwt.return ()
      | Contract_migration.{ label; statement; check_fk = true } :: steps ->
        Logs.debug (fun m -> m "Running %s" label);
        let query (module Connection : Caqti_lwt.CONNECTION) =
          let req = statement |> Caqti_type.(unit ->. unit) ~oneshot:true in
          Connection.exec req () |> Lwt.map Database.raise_error
        in
        let%lwt () = Database.query ?ctx query in
        Logs.debug (fun m -> m "Ran %s" label);
        let%lwt _ = increment ?ctx namespace in
        run steps
      | { label; statement; check_fk = false } :: steps ->
        let%lwt () =
          with_disabled_fk_check ?ctx (fun connection ->
            Logs.debug (fun m -> m "Running %s without fk checks" label);
            let query (module Connection : Caqti_lwt.CONNECTION) =
              let req = statement |> Caqti_type.(unit ->. unit) ~oneshot:true in
              Connection.exec req () |> Lwt.map Database.raise_error
            in
            query connection)
        in
        Logs.debug (fun m -> m "Ran %s" label);
        let%lwt _ = increment ?ctx namespace in
        run steps
    in
    let () =
      match List.length steps with
      | 0 -> Logs.debug (fun m -> m "No migrations to apply for %s" namespace)
      | n -> Logs.debug (fun m -> m "Applying %i migrations for %s" n namespace)
    in
    run steps
  ;;

  let execute_migration ?ctx migration =
    let namespace, _ = migration in
    let%lwt () = setup ?ctx () in
    let%lwt has_state = has ?ctx namespace in
    let%lwt state =
      if has_state
      then (
        let%lwt state = get ?ctx namespace in
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
          raise Contract_migration.Dirty_migration)
        else mark_dirty ?ctx namespace)
      else (
        Logs.debug (fun m -> m "Setting up table for %s" namespace);
        let state = Repo.Migration.create ~namespace in
        let%lwt () = upsert ?ctx state in
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
    let%lwt () =
      Lwt.catch
        (fun () -> execute_steps ?ctx migration_to_apply)
        (fun exn ->
          let err = Printexc.to_string exn in
          Logs.err (fun m ->
            m "Error while running migration '%a': %s" pp migration err);
          raise (Contract_migration.Exception err))
    in
    let%lwt _ = mark_clean ?ctx namespace in
    Lwt.return ()
  ;;

  let execute ?ctx migrations =
    let n = List.length migrations in
    if n > 0
    then
      Logs.info (fun m -> m "Looking at %i migrations" (List.length migrations))
    else Logs.info (fun m -> m "No migrations to execute");
    let rec run migrations =
      match migrations with
      | [] -> Lwt.return ()
      | migration :: migrations ->
        let%lwt () = execute_migration ?ctx migration in
        run migrations
    in
    run migrations
  ;;

  let run_all ?ctx () = execute ?ctx !registered_migrations

  let migrations_status ?ctx ?migrations () =
    let migrations_to_check =
      match migrations with
      | Some migrations -> migrations
      | None -> !registered_migrations
    in
    let%lwt migrations_states = Repo.get_all ?ctx (table ()) in
    let migration_states_namespaces =
      migrations_states
      |> List.map (fun migration_state ->
        migration_state.Database_migration_repo.Migration.namespace)
    in
    let registered_migrations_namespaces =
      migrations_to_check |> List.map fst
    in
    let namespaces_to_check =
      List.concat
        [ migration_states_namespaces; registered_migrations_namespaces ]
      |> CCList.uniq ~eq:String.equal
    in
    Lwt.return
    @@ List.map
         (fun namespace ->
           let migrations = List.assoc_opt namespace migrations_to_check in
           let migration_state =
             List.find_opt
               (fun migration_state ->
                 String.equal
                   migration_state.Database_migration_repo.Migration.namespace
                   namespace)
               migrations_states
           in
           match migrations, migration_state with
           | None, None -> namespace, None
           | None, Some migration_state ->
             ( namespace
             , Some (-migration_state.Database_migration_repo.Migration.version)
             )
           | Some migrations, Some migration_state ->
             let unapplied_migrations_count =
               List.length migrations
               - migration_state.Database_migration_repo.Migration.version
             in
             namespace, Some unapplied_migrations_count
           | Some migrations, None -> namespace, Some (List.length migrations))
         namespaces_to_check
  ;;

  let pending_migrations ?ctx () =
    let%lwt unapplied = migrations_status ?ctx () in
    let rec find_pending result = function
      | (namespace, Some n) :: xs ->
        if n > 0
        then (
          let result = List.cons (namespace, n) result in
          find_pending result xs)
        else find_pending result xs
      | (_, None) :: xs -> find_pending result xs
      | [] -> result
    in
    Lwt.return @@ find_pending [] unapplied
  ;;

  let check_migrations_status ?ctx ?migrations () =
    let%lwt unapplied = migrations_status ?ctx ?migrations () in
    List.iter
      (fun (namespace, count) ->
        match count with
        | None ->
          Logs.warn (fun m ->
            m
              "Could not find registered migrations for namespace '%s'. This \
               implies you removed all migrations of that namespace. \
               Migrations should be append-only. If you intended to remove \
               those migrations, make sure to remove the migration state in \
               your database/other persistence layer."
              namespace)
        | Some count ->
          if count > 0
          then
            Logs.info (fun m ->
              m
                "Unapplied migrations for namespace '%s' detected. Found %s \
                 unapplied migrations, run command 'migrate'."
                namespace
                (Int.to_string count))
          else if count < 0
          then
            Logs.warn (fun m ->
              m
                "Fewer registered migrations found than migration state \
                 indicates for namespace '%s'. Current migration state version \
                 is ahead of registered migrations by %s. This implies you \
                 removed migrations, which should be append-only."
                namespace
                (Int.to_string @@ Int.abs count))
          else ())
      unapplied;
    Lwt.return ()
  ;;

  let start () =
    Core_configuration.require schema;
    let%lwt () = setup () in
    let skip_default_pool_creation =
      Option.value
        ~default:false
        (Core_configuration.read_bool "DATABASE_SKIP_DEFAULT_POOL_CREATION")
    in
    if Core_configuration.is_test () || skip_default_pool_creation
    then Lwt.return ()
    else check_migrations_status ()
  ;;

  let stop () = Lwt.return ()

  let migrate_cmd =
    Core_command.make
      ~name:"migrate"
      ~description:"Runs all pending migrations."
      (fun _ ->
         let%lwt () = Database.start () in
         let%lwt () = start () in
         run_all () |> Lwt.map Option.some)
  ;;

  let lifecycle =
    Core_container.create_lifecycle
      Contract_migration.name
      ~dependencies:(fun () -> [ Database.lifecycle ])
      ~start
      ~stop
  ;;

  let register migrations =
    register_migrations migrations;
    Core_container.Service.create ~commands:[ migrate_cmd ] lifecycle
  ;;
end

module PostgreSql = Make (Database_migration_repo.PostgreSql)
module MariaDb = Make (Database_migration_repo.MariaDb)
