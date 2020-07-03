module type SERVICE = sig
  include Sig.SERVICE

  val register_config :
    Core_ctx.t -> Core_config.Setting.t -> (unit, string) Result.t Lwt.t
end

let key : (module SERVICE) Core.Container.key =
  Core.Container.create_key "config"
