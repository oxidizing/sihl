module type SERVICE = sig
  include Core.Container.SERVICE

  val create_reset_token :
    Core.Ctx.t -> email:string -> (Token.t option, string) Result.t Lwt.t
  (** If there is no user with [email] the return value is None*)

  val reset_password :
    Core.Ctx.t ->
    token:string ->
    password:string ->
    password_confirmation:string ->
    ((unit, string) Result.t, string) Result.t Lwt.t
end
