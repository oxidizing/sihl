module type REPOSITORY = sig
  include Data.Repo.Sig.REPO

  val get_all :
    Core.Ctx.t ->
    query:Data.Ql.t ->
    (User_core.User.t list * Data.Repo.Meta.t, string) Result.t Lwt.t

  val get :
    Core.Ctx.t -> id:string -> (User_core.User.t option, string) Result.t Lwt.t

  val get_by_email :
    Core.Ctx.t ->
    email:string ->
    (User_core.User.t option, string) Result.t Lwt.t

  val insert :
    Core.Ctx.t -> user:User_core.User.t -> (unit, string) Result.t Lwt.t

  val update :
    Core.Ctx.t -> user:User_core.User.t -> (unit, string) Result.t Lwt.t
end

module type SERVICE = sig
  include Core_container.SERVICE

  val get_all :
    Core.Ctx.t ->
    query:Data.Ql.t ->
    (User_core.User.t list * Data.Repo.Meta.t, string) Result.t Lwt.t

  val get :
    Core.Ctx.t ->
    user_id:string ->
    (User_core.User.t option, string) Result.t Lwt.t

  val get_by_email :
    Core.Ctx.t ->
    email:string ->
    (User_core.User.t option, string) Result.t Lwt.t

  val update_password :
    Core.Ctx.t ->
    ?password_policy:(string -> (unit, string) Result.t) ->
    user:User_core.User.t ->
    old_password:string ->
    new_password:string ->
    new_password_confirmation:string ->
    unit ->
    ((User_core.User.t, string) Result.t, string) Result.t Lwt.t

  val update_details :
    Core.Ctx.t ->
    user:User_core.User.t ->
    email:string ->
    username:string option ->
    (User_core.User.t, string) Result.t Lwt.t

  val set_password :
    Core.Ctx.t ->
    ?password_policy:(string -> (unit, string) Result.t) ->
    user:User_core.User.t ->
    password:string ->
    password_confirmation:string ->
    unit ->
    ((User_core.User.t, string) Result.t, string) Result.t Lwt.t

  val create_user :
    Core.Ctx.t ->
    email:string ->
    password:string ->
    username:string option ->
    (User_core.User.t, string) Result.t Lwt.t

  val create_admin :
    Core.Ctx.t ->
    email:string ->
    password:string ->
    username:string option ->
    (User_core.User.t, string) Result.t Lwt.t

  val register :
    Core_ctx.t ->
    ?password_policy:(string -> (unit, string) result) ->
    ?username:string ->
    email:string ->
    password:string ->
    password_confirmation:string ->
    unit ->
    ((User_core.User.t, string) result, string) Lwt_result.t

  val login :
    Core_ctx.t ->
    email:string ->
    password:string ->
    ((User_core.User.t, string) result, string) Lwt_result.t
end
