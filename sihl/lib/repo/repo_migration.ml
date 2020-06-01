module Contract = Core.Contract
module Registry = Core.Registry
module Db = Core.Db
open Base

let ( let* ) = Lwt_result.bind

module Model = struct
  open Contract.Migration.State

  let create ~namespace = { namespace; version = 0; dirty = true }

  let mark_dirty state = { state with dirty = true }

  let mark_clean state = { state with dirty = false }

  let increment state = { state with version = state.version + 1 }

  let steps_to_apply (namespace, steps) { version; _ } =
    (namespace, List.drop steps version)

  let of_tuple (namespace, version, dirty) = { namespace; version; dirty }

  let to_tuple state = (state.namespace, state.version, state.dirty)

  let dirty state = state.dirty
end

module Service = struct
  let setup pool =
    Logs.debug (fun m -> m "MIGRATION: Setting up table if not exists");
    let (module Repository : Contract.Migration.REPOSITORY) =
      Registry.get Contract.Migration.repository
    in
    Db.query_pool (fun c -> Repository.create_table_if_not_exists c ()) pool

  let has pool ~namespace =
    let (module Repository : Contract.Migration.REPOSITORY) =
      Registry.get Contract.Migration.repository
    in

    let* result = Db.query_pool (fun c -> Repository.get c ~namespace) pool in
    Lwt_result.return (Option.is_some result)

  let get pool ~namespace =
    let (module Repository : Contract.Migration.REPOSITORY) =
      Registry.get Contract.Migration.repository
    in

    let* state = Db.query_pool (fun c -> Repository.get c ~namespace) pool in
    Lwt.return
    @@
    match state with
    | Some state -> Ok state
    | None ->
        Error
          (Printf.sprintf "could not get migration state for namespace %s"
             namespace)

  let upsert pool state =
    let (module Repository : Contract.Migration.REPOSITORY) =
      Registry.get Contract.Migration.repository
    in
    Db.query_pool (fun c -> Repository.upsert c state) pool

  let mark_dirty pool ~namespace =
    let* state = get pool ~namespace in
    let dirty_state = Model.mark_dirty state in
    let* () = upsert pool dirty_state in
    Lwt.return @@ Ok dirty_state

  let mark_clean pool ~namespace =
    let* state = get pool ~namespace in
    let clean_state = Model.mark_clean state in
    let* () = upsert pool clean_state in
    Lwt.return @@ Ok clean_state

  let increment pool ~namespace =
    let* state = get pool ~namespace in
    let updated_state = Model.increment state in
    let* () = upsert pool updated_state in
    Lwt.return @@ Ok updated_state
end

let execute_steps migration pool =
  let namespace, steps = migration in
  let open Lwt in
  let rec run steps pool =
    match steps with
    | [] -> Lwt_result.return ()
    | (name, query) :: steps -> (
        Logs.debug (fun m -> m "MIGRATION: Running %s" name);
        Db.query_pool (fun c -> query c ()) pool >>= function
        | Ok () ->
            Logs.debug (fun m -> m "MIGRATION: Ran %s" name);
            let* _ = Service.increment pool ~namespace in
            run steps pool
        | Error err ->
            Logs.err (fun m ->
                m "MIGRATION: Error while running migration for %s %s" namespace
                  err);
            failwith "Error while running migrations" )
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
  run steps pool

let execute_migration migration pool =
  let namespace, _ = migration in
  Logs.debug (fun m -> m "MIGRATION: Execute migrations for %s app" namespace);
  let* () = Service.setup pool in
  let* has_state = Service.has pool ~namespace in
  let* state =
    if has_state then
      let* state = Service.get pool ~namespace in
      if Model.dirty state then (
        let msg =
          "Dirty migration found for app " ^ namespace
          ^ ", has to be fixed manually"
        in
        Logs.err (fun m -> m "MIGRATION: %s" msg);
        failwith msg )
      else Service.mark_dirty pool ~namespace
    else (
      Logs.debug (fun m -> m "MIGRATION: Setting up table for %s app" namespace);
      let state = Model.create ~namespace in
      let* () = Service.upsert pool state in
      Lwt.return @@ Ok state )
  in
  let migration_to_apply = Model.steps_to_apply migration state in
  let* () = execute_steps migration_to_apply pool in
  let* _ = Service.mark_clean pool ~namespace in
  Lwt.return @@ Ok ()

let execute migrations =
  let open Lwt in
  let rec run migrations pool =
    match migrations with
    | [] -> Lwt_result.return ()
    | migration :: migrations -> (
        execute_migration migration pool >>= function
        | Ok () -> run migrations pool
        | Error err -> return (Error err) )
  in
  return (Db.connect ()) >>= run migrations
