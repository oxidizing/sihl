module type SERVICE = sig
  include Sig.SERVICE

  val add_pool : Core_ctx.t -> Core_ctx.t
end

let key : (module SERVICE) Core.Container.key =
  Core.Container.create_key "database"
