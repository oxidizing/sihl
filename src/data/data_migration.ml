open Base
include Data_migration_core.Migration
module Model = Data_migration_core
module Cmd = Data_migration_cmd
module Sig = Data_migration_sig
module Service = Data_migration_service

let empty label = (label, [])

let create_step ~label ?(check_fk = true) statement =
  { label; statement; check_fk }

(* Append the migration step to the list of steps *)
let add_step step (label, steps) = (label, List.concat [ steps; [ step ] ])
