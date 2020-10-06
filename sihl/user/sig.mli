module type REPOSITORY = sig
  include Repository.Sig.REPO
  module DatabaseService : Database.Sig.SERVICE

  val get_all
    :  Core.Ctx.t
    -> query:Database.Ql.t
    -> (Model.User.t list * Repository.Meta.t) Lwt.t

  val get : Core.Ctx.t -> id:string -> Model.User.t option Lwt.t
  val get_by_email : Core.Ctx.t -> email:string -> Model.User.t option Lwt.t
  val insert : Core.Ctx.t -> user:Model.User.t -> unit Lwt.t
  val update : Core.Ctx.t -> user:Model.User.t -> unit Lwt.t
end

module type SERVICE = sig
  include Core.Container.Service.Sig

  val add_user : Model.User.t -> Core.Ctx.t -> Core.Ctx.t
  val require_user_opt : Core.Ctx.t -> Model.User.t option
  val require_user : Core.Ctx.t -> Model.User.t

  val find_all
    :  Core.Ctx.t
    -> query:Database.Ql.t
    -> (Model.User.t list * Repository.Meta.t) Lwt.t

  val find_opt : Core.Ctx.t -> user_id:string -> Model.User.t option Lwt.t
  val find : Core.Ctx.t -> user_id:string -> Model.User.t Lwt.t
  val find_by_email : Core.Ctx.t -> email:string -> Model.User.t Lwt.t
  val find_by_email_opt : Core.Ctx.t -> email:string -> Model.User.t option Lwt.t

  val update_password
    :  Core.Ctx.t
    -> ?password_policy:(string -> (unit, string) Result.t)
    -> user:Model.User.t
    -> old_password:string
    -> new_password:string
    -> new_password_confirmation:string
    -> unit
    -> (Model.User.t, string) Result.t Lwt.t

  val update_details
    :  Core.Ctx.t
    -> user:Model.User.t
    -> email:string
    -> username:string option
    -> Model.User.t Lwt.t

  (** Set the password of a user without knowing the old password.

      This feature is typically used by admins. *)
  val set_password
    :  Core.Ctx.t
    -> ?password_policy:(string -> (unit, string) Result.t)
    -> user:Model.User.t
    -> password:string
    -> password_confirmation:string
    -> unit
    -> (Model.User.t, string) Result.t Lwt.t

  (** Create and store a user. *)
  val create_user
    :  Core.Ctx.t
    -> email:string
    -> password:string
    -> username:string option
    -> Model.User.t Lwt.t

  (** Create and store a user that is also an admin. *)
  val create_admin
    :  Core.Ctx.t
    -> email:string
    -> password:string
    -> username:string option
    -> Model.User.t Lwt.t

  (** Create and store new user.

      Provide [password_policy] to check whether the password fulfills certain criteria. *)
  val register
    :  Core.Ctx.t
    -> ?password_policy:(string -> (unit, string) result)
    -> ?username:string
    -> email:string
    -> password:string
    -> password_confirmation:string
    -> unit
    -> (Model.User.t, string) Result.t Lwt.t

  (** Find user by email if password matches. *)
  val login
    :  Core.Ctx.t
    -> email:string
    -> password:string
    -> (Model.User.t, string) Result.t Lwt.t

  val configure : Core.Configuration.data -> Core.Container.Service.t
end
