open Base
open Core.Contract.Migration.State

let create ~namespace = { namespace; version = 0; dirty = true }

let mark_dirty state = { state with dirty = true }

let mark_clean state = { state with dirty = false }

let increment state = { state with version = state.version + 1 }

let steps_to_apply (namespace, steps) { version; _ } =
  (namespace, List.drop steps version)

let of_tuple (namespace, version, dirty) = { namespace; version; dirty }

let to_tuple state = (state.namespace, state.version, state.dirty)

let dirty state = state.dirty
