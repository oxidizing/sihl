open Base
module Token = User_model.Token
module Sig = User_sig

type t = User_model.User.t

val t_of_sexp : Sexp.t -> t

val sexp_of_t : t -> Sexp.t

val confirmed : t -> bool

val admin : t -> bool

val status : t -> string

val password : t -> string

val username : t -> string option

val email : t -> string

val id : t -> string

val to_yojson : t -> Yojson.Safe.t

val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

val pp : Caml.Format.formatter -> t -> unit

val show : t -> string

val equal : t -> t -> bool

val make :
  id:string ->
  email:string ->
  ?username:string ->
  password:string ->
  status:string ->
  admin:bool ->
  confirmed:bool ->
  unit ->
  t

val confirm : t -> t

val set_user_password : t -> string -> t

val set_user_details : t -> email:string -> username:string option -> t

val is_admin : t -> bool

val is_owner : t -> string -> bool

val is_confirmed : t -> bool

val matches_password : string -> t -> bool

val validate_password : string -> (unit, string) Result.t

val validate :
  t -> old_password:string -> new_password:string -> (unit, string) Result.t

val create :
  email:string ->
  password:string ->
  username:string option ->
  admin:bool ->
  confirmed:bool ->
  t

val system : t

val t : t Caqti_type.t

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

val set_password :
  Opium_kernel.Request.t ->
  user_id:string ->
  password:string ->
  (User_model.User.t, string) Result.t Lwt.t

val update_details :
  Opium_kernel.Request.t ->
  email:string ->
  username:string option ->
  (User_model.User.t, string) Result.t Lwt.t
