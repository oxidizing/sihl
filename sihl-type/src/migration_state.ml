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
