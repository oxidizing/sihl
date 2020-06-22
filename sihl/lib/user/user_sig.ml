module type SERVICE = sig
  include Service.SERVICE

  (* Extract the pure user service part *)
  val get :
    Opium_kernel.Request.t ->
    user_id:string ->
    (User_model.User.t option, string) Result.t Lwt.t

  val get_by_email :
    Opium_kernel.Request.t ->
    email:string ->
    (User_model.User.t option, string) Result.t Lwt.t

  val get_all :
    Opium_kernel.Request.t -> (User_model.User.t list, string) Result.t Lwt.t

  val update_password :
    Opium_kernel.Request.t ->
    email:string ->
    old_password:string ->
    new_password:string ->
    (User_model.User.t, string) Result.t Lwt.t

  val update_details :
    Opium_kernel.Request.t ->
    email:string ->
    username:string option ->
    (User_model.User.t, string) Result.t Lwt.t

  val set_password :
    Opium_kernel.Request.t ->
    user_id:string ->
    password:string ->
    (User_model.User.t, string) Result.t Lwt.t

  (* Extract the following functions into a token service and to the use case layer *)

  val get_by_token :
    Opium_kernel.Request.t ->
    string ->
    (User_model.User.t option, string) Result.t Lwt.t

  val is_valid_auth_token :
    Opium_kernel.Request.t -> string -> (bool, string) Result.t Lwt.t

  val send_registration_email :
    Opium_kernel.Request.t -> User_model.User.t -> (unit, string) Result.t Lwt.t

  val register :
    ?suppress_email:bool ->
    Opium_kernel.Request.t ->
    email:string ->
    password:string ->
    username:string option ->
    (User_model.User.t, string) Result.t Lwt.t

  val create_admin :
    Opium_kernel.Request.t ->
    email:string ->
    password:string ->
    username:string option ->
    (User_model.User.t, string) Result.t Lwt.t

  val logout :
    Opium_kernel.Request.t -> User_model.User.t -> (unit, string) Result.t Lwt.t

  val login :
    Opium_kernel.Request.t ->
    email:string ->
    password:string ->
    (User_model.Token.t, string) Result.t Lwt.t

  val authenticate_credentials :
    Opium_kernel.Request.t ->
    email:string ->
    password:string ->
    (User_model.User.t, string) Result.t Lwt.t

  val token :
    Opium_kernel.Request.t ->
    User_model.User.t ->
    (User_model.Token.t, string) Result.t Lwt.t

  (* TODO move to use case layer *)

  (* val confirm_email :
   *   Opium_kernel.Request.t -> string -> (unit, string) Result.t Lwt.t
   *
   * val request_password_reset :
   *   Opium_kernel.Request.t -> email:string -> (unit, string) Result.t Lwt.t
   *
   * val reset_password :
   *   Opium_kernel.Request.t ->
   *   token:string ->
   *   new_password:string ->
   *   (unit, string) Result.t Lwt.t *)
end

let key : (module SERVICE) Core.Container.key =
  Core.Container.create_key "user.service"
