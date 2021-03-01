let name = "password.reset"

module type Sig = sig
  (** Create and store a reset token.

      Returns [None] if there is no user with [email]. The reset token can be
      used with [reset_password] to set the password without knowing the old
      password. *)
  val create_reset_token : email:string -> string option Lwt.t

  (** Set the password of a user associated with the reset [token]. *)
  val reset_password
    :  token:string
    -> password:string
    -> password_confirmation:string
    -> (unit, string) Result.t Lwt.t

  val register : unit -> Core_container.Service.t

  include Core_container.Service.Sig
end
