type error =
  | AlreadyRegistered
  | IncorrectPassword
  | InvalidPasswordProvided of string
  | DoesNotExist

(* TODO [jerben] add Status.Active and Status.Inactive *)
type t =
  { id : string
  ; email : string
  ; username : string option
  ; password : string
  ; status : string
  ; admin : bool
  ; confirmed : bool
  ; created_at : Ptime.t
  ; updated_at : Ptime.t
  }

exception Exception of string

(* Signature *)

let name = "user"

module type Sig = sig
  include Sihl_core.Container.Service.Sig

  val search
    :  ?sort:[ `Desc | `Asc ]
    -> ?filter:string
    -> int
    -> (t list * int) Lwt.t

  val find_opt : user_id:string -> t option Lwt.t
  val find : user_id:string -> t Lwt.t
  val find_by_email : email:string -> t Lwt.t
  val find_by_email_opt : email:string -> t option Lwt.t

  val update_password
    :  ?password_policy:(string -> (unit, string) Result.t)
    -> user:t
    -> old_password:string
    -> new_password:string
    -> new_password_confirmation:string
    -> unit
    -> (t, string) Result.t Lwt.t

  val update_details
    :  user:t
    -> email:string
    -> username:string option
    -> t Lwt.t

  (** Set the password of a user without knowing the old password.

      This feature is typically used by admins. *)
  val set_password
    :  ?password_policy:(string -> (unit, string) Result.t)
    -> user:t
    -> password:string
    -> password_confirmation:string
    -> unit
    -> (t, string) Result.t Lwt.t

  val create
    :  email:string
    -> password:string
    -> username:string option
    -> admin:bool
    -> confirmed:bool
    -> (t, string) result Lwt.t

  (** Create and store a user. *)
  val create_user
    :  email:string
    -> password:string
    -> username:string option
    -> t Lwt.t

  (** Create and store a user that is also an admin. *)
  val create_admin
    :  email:string
    -> password:string
    -> username:string option
    -> t Lwt.t

  (** Create and store new user.

      Provide [password_policy] to check whether the password fulfills certain
      criteria. *)
  val register_user
    :  ?password_policy:(string -> (unit, string) result)
    -> ?username:string
    -> email:string
    -> password:string
    -> password_confirmation:string
    -> unit
    -> (t, error) Result.t Lwt.t

  (** Find user by email if password matches. *)
  val login : email:string -> password:string -> (t, error) Result.t Lwt.t

  val register : unit -> Sihl_core.Container.Service.t
end
