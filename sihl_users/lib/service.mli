open Sihl_core.Http

module User : sig
  val authenticate : Request.t -> Model.User.t

  val send_registration_email : Request.t -> Model.User.t -> unit Lwt.t

  val register :
    ?suppress_email:bool ->
    Request.t ->
    email:string ->
    password:string ->
    username:string ->
    name:string ->
    Model.User.t Lwt.t

  val create_admin :
    Request.t ->
    email:string ->
    password:string ->
    username:string ->
    name:string ->
    Model.User.t Lwt.t

  val logout : Request.t -> Model.User.t -> unit Lwt.t

  val login :
    Request.t -> email:string -> password:string -> Model.Token.t Lwt.t

  val token : Request.t -> Model.User.t -> Model.Token.t Lwt.t

  val get : Request.t -> Model.User.t -> user_id:string -> Model.User.t Lwt.t

  val get_all : Request.t -> Model.User.t -> Model.User.t list Lwt.t

  val update_password :
    Request.t ->
    Model.User.t ->
    email:string ->
    old_password:string ->
    new_password:string ->
    Model.User.t Lwt.t

  val update_details :
    Request.t ->
    Model.User.t ->
    email:string ->
    username:string ->
    name:string ->
    phone:string option ->
    Model.User.t Lwt.t

  val set_password :
    Request.t ->
    Model.User.t ->
    user_id:string ->
    password:string ->
    Model.User.t Lwt.t

  val confirm_email : Request.t -> string -> unit Lwt.t

  val request_password_reset :
    Request.t -> email:string -> (unit, string) result Lwt.t

  val reset_password :
    Request.t -> token:string -> new_password:string -> unit Lwt.t
end
