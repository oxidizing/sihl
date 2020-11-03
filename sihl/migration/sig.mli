module Database = Sihl_database
module Core = Sihl_core

module type REPO = sig
  module Database : Database.Sig.SERVICE

  val create_table_if_not_exists : Core.Ctx.t -> unit Lwt.t
  val get : Core.Ctx.t -> namespace:string -> Model.t option Lwt.t
  val upsert : Core.Ctx.t -> state:Model.t -> unit Lwt.t
end

module type SERVICE = sig
  include Core.Container.Service.Sig

  (** Register a migration, so it can be run by the service. *)
  val register_migration : Model.Migration.t -> unit

  (** Register multiple migrations. *)
  val register_migrations : Model.Migration.t list -> unit

  (** Get all registered migrations. *)
  val get_migrations : Core.Ctx.t -> Model.Migration.t list Lwt.t

  (** Run a list of migrations. *)
  val execute : Core.Ctx.t -> Model.Migration.t list -> unit Lwt.t

  (** Run all registered migrations. *)
  val run_all : Core.Ctx.t -> unit Lwt.t

  val configure
    :  Model.Migration.t list
    -> Core.Configuration.data
    -> Core.Container.Service.t
end
