module Service : sig
  module type SERVICE = Authn_sig.SERVICE

  val key : (module SERVICE) Core.Container.key
end

val authenticate : Opium_kernel.Request.t -> User.t
