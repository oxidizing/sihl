module Database = Sihl_database
module Core = Sihl_core

module type REPO = sig
  val create_table_if_not_exists : unit -> unit Lwt.t
  val get : namespace:string -> Model.t option Lwt.t
  val upsert : state:Model.t -> unit Lwt.t
end

module type SERVICE = sig
  include Core.Container.Service.Sig

  (** Register a migration, so it can be run by the service. *)
  val register_migration : Model.Migration.t -> unit

  (** Register multiple migrations. *)
  val register_migrations : Model.Migration.t list -> unit

  (** Run a list of migrations. *)
  val execute : Model.Migration.t list -> unit Lwt.t

  (** Run all registered migrations. *)
  val run_all : unit -> unit Lwt.t

  val register : ?migrations:Model.Migration.t list -> unit -> Core.Container.Service.t
end
