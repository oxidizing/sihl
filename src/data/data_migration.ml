open Base
include Data_migration_core.Migration
module Model = Data_migration_core
module Cmd = Data_migration_cmd
module Sig = Data_migration_sig

module Service = struct
  module type SERVICE = Data_migration_sig.SERVICE

  module type REPO = Data_migration_sig.REPO

  module Make = Data_migration_service.Make
  module MariaDb = Data_migration_service.MariaDb

  let mariadb = Data_migration_service.mariadb

  module PostgreSql = Data_migration_service.PostgreSql

  let postgresql = Data_migration_service.postgresql
end

let empty label = (label, [])

let create_step ~label ?(check_fk = true) statement =
  { label; statement; check_fk }

(* Append the migration step to the list of steps *)
let add_step step (label, steps) = (label, List.concat [ steps; [ step ] ])

let execute migrations =
  let (module MigrationService : Service.SERVICE) =
    Core.Container.fetch_service_exn Data_migration_sig.key
  in
  MigrationService.execute migrations

let register ctx migration =
  let (module MigrationService : Service.SERVICE) =
    Core.Container.fetch_service_exn Data_migration_sig.key
  in
  MigrationService.register ctx migration

let get_migrations ctx =
  let (module MigrationService : Service.SERVICE) =
    Core.Container.fetch_service_exn Data_migration_sig.key
  in
  MigrationService.get_migrations ctx

let run_all ctx =
  let (module MigrationService : Service.SERVICE) =
    Core.Container.fetch_service_exn Data_migration_sig.key
  in
  MigrationService.run_all ctx
