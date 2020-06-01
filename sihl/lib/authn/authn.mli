module type AUTHN_SERVICE = sig
  val authenticate : Opium_kernel.Request.t -> User.t
end

val registry_key : (module AUTHN_SERVICE) Core.Registry.Key.t

val authenticate : Opium_kernel.Request.t -> User.t
