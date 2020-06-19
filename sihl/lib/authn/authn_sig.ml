module type SERVICE = sig
  val authenticate : Opium_kernel.Request.t -> User.t
end
