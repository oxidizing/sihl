module Core = Sihl_core
module Database = Sihl_database
module Repository = Sihl_repository

module type REPOSITORY = sig
  include Repository.Sig.REPO

  val lifecycles : Core.Container.Lifecycle.t list
  val get_all : query:Database.Ql.t -> (Model.t list * Repository.Meta.t) Lwt.t
  val get : id:string -> Model.t option Lwt.t
  val get_by_email : email:string -> Model.t option Lwt.t
  val insert : user:Model.t -> unit Lwt.t
  val update : user:Model.t -> unit Lwt.t
end

module type SERVICE = sig
  include Core.Container.Service.Sig

  val find_all : query:Database.Ql.t -> (Model.t list * Repository.Meta.t) Lwt.t
  val find_opt : user_id:string -> Model.t option Lwt.t
  val find : user_id:string -> Model.t Lwt.t
  val find_by_email : email:string -> Model.t Lwt.t
  val find_by_email_opt : email:string -> Model.t option Lwt.t

  val update_password
    :  ?password_policy:(string -> (unit, string) Result.t)
    -> user:Model.t
    -> old_password:string
    -> new_password:string
    -> new_password_confirmation:string
    -> unit
    -> (Model.t, string) Result.t Lwt.t

  val update_details
    :  user:Model.t
    -> email:string
    -> username:string option
    -> Model.t Lwt.t

  (** Set the password of a user without knowing the old password.

      This feature is typically used by admins. *)
  val set_password
    :  ?password_policy:(string -> (unit, string) Result.t)
    -> user:Model.t
    -> password:string
    -> password_confirmation:string
    -> unit
    -> (Model.t, string) Result.t Lwt.t

  (** Create and store a user. *)
  val create_user
    :  email:string
    -> password:string
    -> username:string option
    -> Model.t Lwt.t

  (** Create and store a user that is also an admin. *)
  val create_admin
    :  email:string
    -> password:string
    -> username:string option
    -> Model.t Lwt.t

  (** Create and store new user.

      Provide [password_policy] to check whether the password fulfills certain criteria. *)
  val register_user
    :  ?password_policy:(string -> (unit, string) result)
    -> ?username:string
    -> email:string
    -> password:string
    -> password_confirmation:string
    -> unit
    -> (Model.t, Model.Error.t) Result.t Lwt.t

  (** Find user by email if password matches. *)
  val login : email:string -> password:string -> (Model.t, Model.Error.t) Result.t Lwt.t

  val register : unit -> Core.Container.Service.t
end
