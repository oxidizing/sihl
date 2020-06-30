module type SERVICE = sig
  include Sig.SERVICE

  val authenticate : Core.Ctx.t -> User.t
end
