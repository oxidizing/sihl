exception Exception of string

type t =
  { namespace : string
  ; version : int
  ; dirty : bool
  }

let create ~namespace = { namespace; version = 0; dirty = true }
let mark_dirty state = { state with dirty = true }
let mark_clean state = { state with dirty = false }
let increment state = { state with version = state.version + 1 }

let steps_to_apply (namespace, steps) { version; _ } =
  namespace, CCList.drop version steps
;;

let of_tuple (namespace, version, dirty) = { namespace; version; dirty }
let to_tuple state = state.namespace, state.version, state.dirty
let dirty state = state.dirty

module Migration = struct
  type step =
    { label : string
    ; statement : string
    ; check_fk : bool
    }
  [@@deriving show, eq]

  type t = string * step list [@@deriving show, eq]
end

module Registry = struct
  let registry : Migration.t list ref = ref []
  let get_all () = !registry
  let register migration = registry := List.concat [ !registry; [ migration ] ]
  let register_migrations migrations = registry := List.concat [ !registry; migrations ]
end
