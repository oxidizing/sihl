module type REPO = sig
  val create_table_if_not_exists :
    Data_db_core.connection -> (unit, string) Result.t Lwt.t

  val get :
    Data_db_core.connection ->
    namespace:string ->
    (Data_migration_core.t option, string) Result.t Lwt.t

  val upsert :
    Data_db_core.connection ->
    state:Data_migration_core.t ->
    (unit, string) Result.t Lwt.t
end

module type SERVICE = sig
  include Core_container.SERVICE

  val register :
    Core.Ctx.t -> Data_migration_core.Migration.t -> (unit, string) Lwt_result.t

  val get_migrations :
    Core.Ctx.t -> (Data_migration_core.Migration.t list, string) Lwt_result.t

  val execute :
    Core.Ctx.t ->
    Data_migration_core.Migration.t list ->
    (unit, string) Result.t Lwt.t

  val run_all : Core.Ctx.t -> (unit, string) Lwt_result.t
end
