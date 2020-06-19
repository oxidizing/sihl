open Base

let ( let* ) = Lwt_result.bind

include Migration_model.Migration
module Model = Migration_model

module Service = struct
  module type SERVICE = Migration_sig.SERVICE

  module type REPO = Migration_sig.REPO

  module Make = Migration_service.Make
  module MariaDb = Migration_service.MariaDb

  let mariadb = Migration_service.mariadb

  module PostgreSql = Migration_service.PostgreSql

  let postgresql = Migration_service.postgresql
end

let empty label = (label, [])

let create_step ~label ?(check_fk = true) statement =
  { label; statement; check_fk }

(* Append the migration step to the list of steps *)
let add_step step (label, steps) = (label, List.concat [ steps; [ step ] ])

let execute_steps migration conn =
  let (module Service : Service.SERVICE) =
    Core.Container.fetch_exn Migration_service.key
  in
  let module Connection = (val conn : Caqti_lwt.CONNECTION) in
  let namespace, steps = migration in
  let open Lwt in
  let rec run steps conn =
    match steps with
    | [] -> Lwt_result.return ()
    | { label; statement; check_fk = true } :: steps -> (
        Logs.debug (fun m -> m "MIGRATION: Running %s" label);
        let req = Caqti_request.exec Caqti_type.unit statement in
        Connection.exec req () >>= function
        | Ok () ->
            Logs.debug (fun m -> m "MIGRATION: Ran %s" label);
            let* _ = Service.increment conn ~namespace in
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
        Logs.debug (fun m -> m "MIGRATION: Running %s without fk checks" label);
        let req = Caqti_request.exec Caqti_type.unit statement in
        Connection.exec req () >>= function
        | Ok () ->
            let* _ = Repo.set_fk_check conn true in
            Logs.debug (fun m -> m "MIGRATION: Ran %s" label);
            let* _ = Service.increment conn ~namespace in
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
  let (module Service : Service.SERVICE) =
    Core.Container.fetch_exn Migration_service.key
  in
  let namespace, _ = migration in
  Logs.debug (fun m -> m "MIGRATION: Execute migrations for app %s" namespace);
  let* () = Service.setup conn in
  let* has_state = Service.has conn ~namespace in
  let* state =
    if has_state then
      let* state = Service.get conn ~namespace in
      if Model.dirty state then (
        let msg =
          Printf.sprintf
            "Dirty migration found for app %s, has to be fixed manually"
            namespace
        in
        Logs.err (fun m -> m "MIGRATION: %s" msg);
        failwith msg )
      else Service.mark_dirty conn ~namespace
    else (
      Logs.debug (fun m -> m "MIGRATION: Setting up table for %s app" namespace);
      let state = Model.create ~namespace in
      let* () = Service.upsert conn state in
      Lwt.return @@ Ok state )
  in
  let migration_to_apply = Model.steps_to_apply migration state in
  let* () = execute_steps migration_to_apply conn in
  let* _ = Service.mark_clean conn ~namespace in
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
    Caqti_lwt.Pool.use (fun conn -> run migrations conn >|= to_caqti_error) pool
  in
  result |> Lwt_result.map_err Caqti_error.show
