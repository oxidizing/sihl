module type SERVICE = sig
  include Core_container.SERVICE

  val start_server : Core.Ctx.t -> unit Lwt.t

  val register_routes :
    Core_ctx.t ->
    Web_server_core.stacked_routes ->
    (unit, string) Result.t Lwt.t
end
