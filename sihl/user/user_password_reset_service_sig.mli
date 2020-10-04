module type SERVICE = sig
  include Core.Container.Service.Sig

  (** Create and store a reset token.

      Returns [None] if there is no user with [email]. The reset token can be used with
      [reset_password] to set the password without knowing the old password. *)
  val create_reset_token : Core.Ctx.t -> email:string -> Token.t option Lwt.t

  (** Set the password of a user associated with the reset [token]. *)
  val reset_password
    :  Core.Ctx.t
    -> token:string
    -> password:string
    -> password_confirmation:string
    -> (unit, string) Result.t Lwt.t

  val configure : Core.Configuration.data -> Core.Container.Service.t
end
