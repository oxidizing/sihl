let name = "password.reset"

module type Sig = sig
  (** [create_reset_token ?ctx ~email] creates and stores a reset token.

      Returns [None] if there is no user with [email]. The reset token can be
      used with [reset_password] to set the password without knowing the old
      password. *)
  val create_reset_token
    :  ?ctx:(string * string) list
    -> email:string
    -> string option Lwt.t

  (** [reset_password ?ctx ~token ~password ~password_confirmation] sets the
      password of a user associated with the reset [token]. *)
  val reset_password
    :  ?ctx:(string * string) list
    -> token:string
    -> password:string
    -> password_confirmation:string
    -> (unit, string) Result.t Lwt.t

  val register : unit -> Core_container.Service.t

  include Core_container.Service.Sig
end
