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

module State = struct
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
end

(* Signature *)
let name = "sihl.service.migration"

exception Exception of string

module type Sig = sig
  include Sihl_core.Container.Service.Sig

  (** Register a migration, so it can be run by the service. *)
  val register_migration : t -> unit

  (** Register multiple migrations. *)
  val register_migrations : t list -> unit

  (** Run a list of migrations. *)
  val execute : t list -> unit Lwt.t

  (** Run all registered migrations. *)
  val run_all : unit -> unit Lwt.t

  val register : ?migrations:t list -> unit -> Sihl_core.Container.Service.t
end
