module type REPOSITORY = sig
  include Sig.REPO

  val get_all :
    Core.Db.connection -> (User_model.User.t list, string) Result.t Lwt.t

  val get :
    Core.Db.connection ->
    id:string ->
    (User_model.User.t option, string) Result.t Lwt.t

  val get_by_email :
    Core.Db.connection ->
    email:string ->
    (User_model.User.t option, string) Result.t Lwt.t

  val insert :
    Core.Db.connection ->
    user:User_model.User.t ->
    (unit, string) Result.t Lwt.t

  val update :
    Core.Db.connection ->
    user:User_model.User.t ->
    (unit, string) Result.t Lwt.t
end

module type SERVICE = sig
  include Sig.SERVICE

  val get_all : Core.Ctx.t -> (User_model.User.t list, string) Result.t Lwt.t

  val get :
    Core.Ctx.t ->
    user_id:string ->
    (User_model.User.t option, string) Result.t Lwt.t

  val get_by_email :
    Core.Ctx.t ->
    email:string ->
    (User_model.User.t option, string) Result.t Lwt.t

  val update_password :
    Core.Ctx.t ->
    email:string ->
    old_password:string ->
    new_password:string ->
    (User_model.User.t, string) Result.t Lwt.t

  val update_details :
    Core.Ctx.t ->
    email:string ->
    username:string option ->
    (User_model.User.t, string) Result.t Lwt.t

  val set_password :
    Core.Ctx.t ->
    user_id:string ->
    password:string ->
    (User_model.User.t, string) Result.t Lwt.t

  val create_user :
    Core.Ctx.t ->
    email:string ->
    password:string ->
    username:string option ->
    (User_model.User.t, string) Result.t Lwt.t

  val create_admin :
    Core.Ctx.t ->
    email:string ->
    password:string ->
    username:string option ->
    (User_model.User.t, string) Result.t Lwt.t
end

let key : (module SERVICE) Core.Container.key =
  Core.Container.create_key "user.service"
