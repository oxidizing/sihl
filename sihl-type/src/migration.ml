module Map = Map.Make (String)

type step =
  { label : string
  ; statement : string
  ; check_fk : bool
  }
[@@deriving show, eq]

type steps = step list [@@deriving show, eq]
type t = string * steps [@@deriving show, eq]

let create_step ~label ?(check_fk = true) statement = { label; check_fk; statement }
let empty namespace = namespace, []

(* Append the migration step to the list of steps *)
let add_step step (label, steps) = label, List.concat [ steps; [ step ] ]

let get_migrations_status migrations_states all_migrations =
  List.map
    (fun migrations_state ->
      let namespace = Migration_state.namespace migrations_state in
      let migrations = Map.find_opt namespace all_migrations in
      match migrations with
      | None -> namespace, None
      | Some migrations ->
        let unapplied_migrations_count =
          List.length migrations - Migration_state.version migrations_state
        in
        namespace, Some unapplied_migrations_count)
    migrations_states
;;
