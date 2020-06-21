module type SERVICE = sig
  include Service.SERVICE

  val is_valid_auth_token : Opium_kernel.Request.t -> string -> bool Lwt.t

  val get :
    Opium_kernel.Request.t ->
    User_model.User.t ->
    user_id:string ->
    User_model.User.t Lwt.t

  val get_by_token : Opium_kernel.Request.t -> string -> User_model.User.t Lwt.t

  val get_by_email :
    Opium_kernel.Request.t -> email:string -> User_model.User.t Lwt.t

  val get_all :
    Opium_kernel.Request.t -> User_model.User.t -> User_model.User.t list Lwt.t

  val send_registration_email :
    Opium_kernel.Request.t -> User_model.User.t -> unit Lwt.t

  val register :
    ?suppress_email:bool ->
    Opium_kernel.Request.t ->
    email:string ->
    password:string ->
    username:string option ->
    User_model.User.t Lwt.t

  val create_admin :
    Opium_kernel.Request.t ->
    email:string ->
    password:string ->
    username:string option ->
    User_model.User.t Lwt.t

  val logout : Opium_kernel.Request.t -> User_model.User.t -> unit Lwt.t

  val login :
    Opium_kernel.Request.t ->
    email:string ->
    password:string ->
    User_model.Token.t Lwt.t

  val authenticate_credentials :
    Opium_kernel.Request.t ->
    email:string ->
    password:string ->
    User_model.User.t Lwt.t

  val token :
    Opium_kernel.Request.t -> User_model.User.t -> User_model.Token.t Lwt.t

  val update_password :
    Opium_kernel.Request.t ->
    User_model.User.t ->
    email:string ->
    old_password:string ->
    new_password:string ->
    User_model.User.t Lwt.t

  val update_details :
    Opium_kernel.Request.t ->
    User_model.User.t ->
    email:string ->
    username:string option ->
    User_model.User.t Lwt.t

  val set_password :
    Opium_kernel.Request.t ->
    User_model.User.t ->
    user_id:string ->
    password:string ->
    User_model.User.t Lwt.t

  val confirm_email : Opium_kernel.Request.t -> string -> unit Lwt.t

  val request_password_reset :
    Opium_kernel.Request.t -> email:string -> unit Lwt.t

  val reset_password :
    Opium_kernel.Request.t -> token:string -> new_password:string -> unit Lwt.t
end

let key : (module SERVICE) Core.Container.key =
  Core.Container.create_key "user.service"
