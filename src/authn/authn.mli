module Service : sig
  module type SERVICE = Authn_sig.SERVICE

  val key : (module SERVICE) Core.Container.key
end

val authenticate : Core.Ctx.t -> User.t
