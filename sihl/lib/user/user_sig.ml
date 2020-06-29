module type SERVICE = sig
  include Sig.SERVICE

  (* Extract the pure user service part *)
  val get :
    Core.Ctx.t ->
    user_id:string ->
    (User_model.User.t option, string) Result.t Lwt.t

  val get_by_email :
    Core.Ctx.t ->
    email:string ->
    (User_model.User.t option, string) Result.t Lwt.t

  val get_all : Core.Ctx.t -> (User_model.User.t list, string) Result.t Lwt.t

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

  (* Extract the following functions into a token service and to the use case layer *)

  val get_by_token :
    Core.Ctx.t -> string -> (User_model.User.t option, string) Result.t Lwt.t

  val is_valid_auth_token :
    Core.Ctx.t -> string -> (bool, string) Result.t Lwt.t

  val send_registration_email :
    Core.Ctx.t -> User_model.User.t -> (unit, string) Result.t Lwt.t

  val register :
    ?suppress_email:bool ->
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

  val logout : Core.Ctx.t -> User_model.User.t -> (unit, string) Result.t Lwt.t

  val login :
    Core.Ctx.t ->
    email:string ->
    password:string ->
    (User_model.Token.t, string) Result.t Lwt.t

  val authenticate_credentials :
    Core.Ctx.t ->
    email:string ->
    password:string ->
    (User_model.User.t, string) Result.t Lwt.t

  val token :
    Core.Ctx.t ->
    User_model.User.t ->
    (User_model.Token.t, string) Result.t Lwt.t

  (* TODO move to use case layer *)

  (* val confirm_email :
   *   Core.Ctx.t -> string -> (unit, string) Result.t Lwt.t
   *
   * val request_password_reset :
   *   Core.Ctx.t -> email:string -> (unit, string) Result.t Lwt.t
   *
   * val reset_password :
   *   Core.Ctx.t ->
   *   token:string ->
   *   new_password:string ->
   *   (unit, string) Result.t Lwt.t *)
end

let key : (module SERVICE) Core.Container.key =
  Core.Container.create_key "user.service"
