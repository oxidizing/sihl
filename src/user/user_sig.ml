module type REPOSITORY = sig
  include Data.Repo.Sig.REPO

  val get_all :
    Core.Ctx.t ->
    query:Data.Ql.t ->
    (User_core.User.t list * Data.Repo.Meta.t) Lwt.t

  val get : Core.Ctx.t -> id:string -> User_core.User.t option Lwt.t

  val get_by_email : Core.Ctx.t -> email:string -> User_core.User.t option Lwt.t

  val insert : Core.Ctx.t -> user:User_core.User.t -> unit Lwt.t

  val update : Core.Ctx.t -> user:User_core.User.t -> unit Lwt.t
end

module type SERVICE = sig
  include Core_container.SERVICE

  val add_user : User_core.User.t -> Core.Ctx.t -> Core.Ctx.t

  val require_user_opt : Core.Ctx.t -> User_core.User.t option

  val require_user : Core.Ctx.t -> User_core.User.t

  val find_all :
    Core.Ctx.t ->
    query:Data.Ql.t ->
    (User_core.User.t list * Data.Repo.Meta.t) Lwt.t

  val find_opt : Core.Ctx.t -> user_id:string -> User_core.User.t option Lwt.t

  val find : Core.Ctx.t -> user_id:string -> User_core.User.t Lwt.t

  val find_by_email : Core.Ctx.t -> email:string -> User_core.User.t Lwt.t

  val find_by_email_opt :
    Core.Ctx.t -> email:string -> User_core.User.t option Lwt.t

  val update_password :
    Core.Ctx.t ->
    ?password_policy:(string -> (unit, string) Result.t) ->
    user:User_core.User.t ->
    old_password:string ->
    new_password:string ->
    new_password_confirmation:string ->
    unit ->
    (User_core.User.t, string) Result.t Lwt.t

  val update_details :
    Core.Ctx.t ->
    user:User_core.User.t ->
    email:string ->
    username:string option ->
    User_core.User.t Lwt.t

  val set_password :
    Core.Ctx.t ->
    ?password_policy:(string -> (unit, string) Result.t) ->
    user:User_core.User.t ->
    password:string ->
    password_confirmation:string ->
    unit ->
    (User_core.User.t, string) Result.t Lwt.t
  (** Set the password of a user without knowing the old password.

      This feature is typically used by admins. *)

  val create_user :
    Core.Ctx.t ->
    email:string ->
    password:string ->
    username:string option ->
    User_core.User.t Lwt.t
  (** Create and store a user. *)

  val create_admin :
    Core.Ctx.t ->
    email:string ->
    password:string ->
    username:string option ->
    User_core.User.t Lwt.t
  (** Create and store a user that is also an admin. *)

  val register :
    Core_ctx.t ->
    ?password_policy:(string -> (unit, string) result) ->
    ?username:string ->
    email:string ->
    password:string ->
    password_confirmation:string ->
    unit ->
    (User_core.User.t, string) Result.t Lwt.t
  (** Create and store new user.

      Provide [password_policy] to check whether the password fulfills certain criteria.
*)

  val login :
    Core_ctx.t ->
    email:string ->
    password:string ->
    (User_core.User.t, string) Result.t Lwt.t
  (** Find user by email if password matches. *)
end
