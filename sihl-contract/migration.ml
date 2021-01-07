type step =
  { label : string
  ; statement : string
  ; check_fk : bool
  }

type t = string * step list

let name = "migration"

exception Exception of string
exception Dirty_migration

module type Sig = sig
  include Sihl_core.Container.Service.Sig

  (** [register_migration migration] registers a migration [migration] with the
      migration service so it can be executed with `run_all`. *)
  val register_migration : t -> unit

  (** [register_migrations migrations] registers migrations [migrations] with
      the migration service so it can be executed with `run_all`. *)
  val register_migrations : t list -> unit

  (** [execute migrations] runs all migrations [migrations]. *)
  val execute : t list -> unit Lwt.t

  (** [run_all ()] runs all migrations that have been registered. *)
  val run_all : unit -> unit Lwt.t

  val register : ?migrations:t list -> unit -> Sihl_core.Container.Service.t
end
