module type SERVICE = sig
  include Core_container.SERVICE

  val find_user_in_session :
    Core.Ctx.t -> (User.t option, string) Result.t Lwt.t

  val authenticate_session :
    Core.Ctx.t -> User.t -> (unit, string) Result.t Lwt.t

  val unauthenticate_session : Core.Ctx.t -> (unit, string) Result.t Lwt.t
end
