open Base
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

let execute migrations =
  (* List.map
   *   ~f:(fun migration ->
   *     Logs.err (fun m ->
   *         m "Executing migration %a" Model.Migration.pp migration))
   *   migrations
   * |> ignore; *)
  let (module MigrationService : Service.SERVICE) =
    Core.Container.fetch_service_exn Migration_sig.key
  in
  MigrationService.execute migrations

let register req migration =
  let (module MigrationService : Service.SERVICE) =
    Core.Container.fetch_service_exn Migration_sig.key
  in
  MigrationService.register req migration

let get_migrations req =
  let (module MigrationService : Service.SERVICE) =
    Core.Container.fetch_service_exn Migration_sig.key
  in
  MigrationService.get_migrations req
