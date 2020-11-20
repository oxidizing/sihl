open Sihl_type

exception Exception of string

module type Sig = sig
  include Sihl_core.Container.Service.Sig

  (** Register a migration, so it can be run by the service. *)
  val register_migration : Migration.t -> unit

  (** Register multiple migrations. *)
  val register_migrations : Migration.t list -> unit

  (** Run a list of migrations. *)
  val execute : Migration.t list -> unit Lwt.t

  (** Run all registered migrations. *)
  val run_all : unit -> unit Lwt.t

  val register : ?migrations:Migration.t list -> unit -> Sihl_core.Container.Service.t
end
