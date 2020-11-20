type step =
  { label : string
  ; statement : string
  ; check_fk : bool
  }
[@@deriving show, eq]

type t = string * step list [@@deriving show, eq]

let create_step ~label ?(check_fk = true) statement = { label; check_fk; statement }
let empty namespace = namespace, []

(* Append the migration step to the list of steps *)
let add_step step (label, steps) = label, List.concat [ steps; [ step ] ]
