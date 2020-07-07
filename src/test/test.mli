val services :
  Core.Ctx.t ->
  Core.Container.binding list ->
  before_start:(unit -> unit Lwt.t) ->
  unit Lwt.t

val app :
  Core.Ctx.t ->
  config:Config.t ->
  services:Core.Container.binding list ->
  unit Lwt.t

val middleware_stack :
  Core.Ctx.t ->
  ?handler:Web.Route.handler ->
  Web.Middleware.stack ->
  Web.Res.t Lwt.t

val seed : Core.Ctx.t -> (Core.Ctx.t -> ('a, string) Result.t Lwt.t) -> 'a Lwt.t

val start_app : (module App_sig.APP) -> unit Lwt.t

val stop_app : unit -> unit Lwt.t

val clean : unit -> unit Lwt.t

val migrate : unit -> unit Lwt.t
