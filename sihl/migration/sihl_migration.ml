include Model.Migration
module Service = Service

let empty label = label, []
let create_step ~label ?(check_fk = true) statement = { label; statement; check_fk }

(* Append the migration step to the list of steps *)
let add_step step (label, steps) = label, List.concat [ steps; [ step ] ]

module Sig = Sig
