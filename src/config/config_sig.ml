module type SERVICE = sig
  include Core_container.SERVICE

  val register_config :
    Core_ctx.t -> Config_core.Config.t -> (unit, string) Result.t Lwt.t
end

let key : (module SERVICE) Core_container.key =
  Core_container.create_key "config"
