module Make : functor (MigrationService : Data_migration_sig.SERVICE) -> sig
  val services :
    Core_ctx.t ->
    config:Config.t ->
    services:(module Core_container.SERVICE) list ->
    unit Lwt.t
end

val middleware_stack :
  Core.Ctx.t ->
  ?handler:Web.Route.handler ->
  Web.Middleware.stack ->
  Web.Res.t Lwt.t

val seed : Core.Ctx.t -> (Core.Ctx.t -> ('a, string) Result.t Lwt.t) -> 'a Lwt.t
