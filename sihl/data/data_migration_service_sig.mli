module type REPO = sig
  module Database : Data_db_service_sig.SERVICE

  val create_table_if_not_exists : Core.Ctx.t -> unit Lwt.t
  val get : Core.Ctx.t -> namespace:string -> Data_migration_core.t option Lwt.t
  val upsert : Core.Ctx.t -> state:Data_migration_core.t -> unit Lwt.t
end

module type SERVICE = sig
  include Core.Container.Service.Sig

  (** Register a migration, so it can be run by the service. *)
  val register : Data_migration_core.Migration.t -> unit

  (** Get all registered migrations. *)
  val get_migrations : Core.Ctx.t -> Data_migration_core.Migration.t list Lwt.t

  (** Run a list of migrations. *)
  val execute : Core.Ctx.t -> Data_migration_core.Migration.t list -> unit Lwt.t

  (** Run all registered migrations. *)
  val run_all : Core.Ctx.t -> unit Lwt.t

  val configure : Core.Configuration.data -> Core.Container.Service.t
end
