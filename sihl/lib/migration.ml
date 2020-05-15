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

module State = struct
  module PostgresRepository : Contract.Migration.REPOSITORY = struct
    open Contract.Migration.State

    let create_table_if_not_exists =
      [%rapper
        execute
          {sql|
CREATE TABLE IF NOT EXISTS core_migration_state (
  namespace VARCHAR(128) NOT NULL PRIMARY KEY,
  version INTEGER,
  dirty BOOL NOT NULL
);
 |sql}]

    let get =
      [%rapper
        get_opt
          {sql|
SELECT
  @string{namespace},
  @int{version},
  @bool{dirty}
FROM core_migration_state
WHERE namespace = %string{namespace};
|sql}
          record_out]

    let upsert =
      [%rapper
        execute
          {sql|
INSERT INTO core_migration_state (
  namespace,
  version,
  dirty
) VALUES (
  %string{namespace},
  %int{version},
  %bool{dirty}
) ON CONFLICT (namespace)
DO UPDATE SET version = %int{version},
dirty = %bool{dirty}
|sql}
          record_in]
  end

  module MariaDbRepository : Contract.Migration.REPOSITORY = struct
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
      Connection.exec request

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

    let upsert connection state =
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

  module Service = struct
    let setup pool =
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
            (Printf.sprintf "could not get migration state for namespace=%s"
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
end

let execute_steps migration pool =
  let namespace, steps = migration in
  let open Lwt in
  let rec run steps pool =
    match steps with
    | [] -> Lwt_result.return ()
    | (name, query) :: steps -> (
        Logs.info (fun m -> m "running: %s\n" name);
        Db.query_pool (fun c -> query c ()) pool >>= function
        | Ok () ->
            Logs.info (fun m -> m "ran: %s\n" name);
            let* _ = State.Service.increment pool ~namespace in
            run steps pool
        | Error err ->
            Logs_lwt.err (fun m ->
                m "error while running migration for %s msg=%s" namespace err)
            >>= fun () -> return (Error err) )
  in
  ( match List.length steps with
  | 0 -> Logs_lwt.info (fun m -> m "no migrations to apply for %s\n" namespace)
  | n ->
      Logs_lwt.info (fun m -> m "applying %i migrations for %s\n" n namespace)
  )
  >>= fun () -> run steps pool

let execute_migration migration pool =
  let namespace, _ = migration in
  let* () = State.Service.setup pool in
  let* has_state = State.Service.has pool ~namespace in
  let* state =
    if has_state then
      let* state = State.Service.get pool ~namespace in
      if Model.dirty state then
        Lwt.return
        @@ Error
             (Printf.sprintf
                "dirty migration found for namespace %s, please fix manually"
                namespace)
      else State.Service.mark_dirty pool ~namespace
    else
      let state = Model.create ~namespace in
      let* () = State.Service.upsert pool state in
      Lwt.return @@ Ok state
  in
  let migration_to_apply = Model.steps_to_apply migration state in
  let* () = execute_steps migration_to_apply pool in
  let* _ = State.Service.mark_clean pool ~namespace in
  Lwt.return @@ Ok ()

module PostgresRepository = State.PostgresRepository
module MariaDbRepository = State.MariaDbRepository

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
