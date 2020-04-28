open Base

type migration_error = Caqti_error.t

type migration_operation =
  Caqti_lwt.connection -> unit -> (unit, migration_error) Result.t Lwt.t

type migration_step = string * migration_operation

type migration = string * migration_step list

module Model = struct
  type t = { namespace : string; version : int; dirty : bool }
  [@@deriving fields]

  let create ~namespace = { namespace; version = 0; dirty = true }

  let mark_dirty state = { state with dirty = true }

  let mark_clean state = { state with dirty = false }

  let increment state = { state with version = state.version + 1 }

  let steps_to_apply (namespace, steps) { version; _ } =
    (namespace, List.drop steps version)

  let of_tuple (namespace, version, dirty) = { namespace; version; dirty }

  let to_tuple state = (state.namespace, state.version, state.dirty)
end
