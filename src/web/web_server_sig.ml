module type SERVICE = sig
  include Core_container.SERVICE

  val register_routes :
    Core_ctx.t ->
    Web_server_core.stacked_routes ->
    (unit, string) Result.t Lwt.t
end

let key : (module SERVICE) Core.Container.key =
  Core.Container.create_key "database"
