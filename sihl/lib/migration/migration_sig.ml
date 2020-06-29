module type REPO = sig
  val create_table_if_not_exists :
    Core.Db.connection -> (unit, string) Result.t Lwt.t

  val get :
    Core.Db.connection ->
    namespace:string ->
    (Migration_model.t option, string) Result.t Lwt.t

  val upsert :
    Core.Db.connection ->
    state:Migration_model.t ->
    (unit, string) Result.t Lwt.t
end

module type SERVICE = sig
  include Sig.SERVICE

  val register :
    Core.Ctx.t -> Migration_model.Migration.t -> (unit, string) Lwt_result.t

  val get_migrations :
    Core.Ctx.t -> (Migration_model.Migration.t list, string) Lwt_result.t

  val execute :
    Migration_model.Migration.t list -> (unit, string) Result.t Lwt.t
end

let key : (module SERVICE) Core.Container.key =
  Core.Container.create_key "migration.service"
