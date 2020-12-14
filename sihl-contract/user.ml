open Sihl_type

module type Sig = sig
  include Sihl_core.Container.Service.Sig

  val find_all : query:Database.Ql.t -> (User.t list * int) Lwt.t
  val find_opt : user_id:string -> User.t option Lwt.t
  val find : user_id:string -> User.t Lwt.t
  val find_by_email : email:string -> User.t Lwt.t
  val find_by_email_opt : email:string -> User.t option Lwt.t

  val update_password
    :  ?password_policy:(string -> (unit, string) Result.t)
    -> user:User.t
    -> old_password:string
    -> new_password:string
    -> new_password_confirmation:string
    -> unit
    -> (User.t, string) Result.t Lwt.t

  val update_details
    :  user:User.t
    -> email:string
    -> username:string option
    -> User.t Lwt.t

  (** Set the password of a user without knowing the old password.

      This feature is typically used by admins. *)
  val set_password
    :  ?password_policy:(string -> (unit, string) Result.t)
    -> user:User.t
    -> password:string
    -> password_confirmation:string
    -> unit
    -> (User.t, string) Result.t Lwt.t

  (** Create and store a user. *)
  val create_user
    :  email:string
    -> password:string
    -> username:string option
    -> User.t Lwt.t

  (** Create and store a user that is also an admin. *)
  val create_admin
    :  email:string
    -> password:string
    -> username:string option
    -> User.t Lwt.t

  (** Create and store new user.

      Provide [password_policy] to check whether the password fulfills certain criteria. *)
  val register_user
    :  ?password_policy:(string -> (unit, string) result)
    -> ?username:string
    -> email:string
    -> password:string
    -> password_confirmation:string
    -> unit
    -> (User.t, User.Error.t) Result.t Lwt.t

  (** Find user by email if password matches. *)
  val login : email:string -> password:string -> (User.t, User.Error.t) Result.t Lwt.t

  val register : unit -> Sihl_core.Container.Service.t

  module Seed : sig
    val admin : email:string -> password:string -> User.t Lwt.t
    val user : email:string -> password:string -> ?username:string -> unit -> User.t Lwt.t
  end
end
