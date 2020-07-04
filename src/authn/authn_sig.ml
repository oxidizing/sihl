module type SERVICE = sig
  include Core_container.SERVICE

  val authenticate : Core.Ctx.t -> User.t
end
