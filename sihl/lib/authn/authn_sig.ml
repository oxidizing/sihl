module type SERVICE = sig
  val authenticate : Core.Ctx.t -> User.t
end
