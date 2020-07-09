open Base
module Sig = User_sig
module Authz = User_authz
module Service = User_service
module Seed = User_seed
module Cmd = User_cmd
module Admin = User_admin

type t = User_core.User.t

val ctx_add_user : t -> Core.Ctx.t -> Core.Ctx.t

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
  Core.Ctx.t ->
  user_id:string ->
  (User_core.User.t option, string) Result.t Lwt.t

val get_by_email :
  Core.Ctx.t -> email:string -> (User_core.User.t option, string) Result.t Lwt.t

val get_all : Core.Ctx.t -> (User_core.User.t list, string) Result.t Lwt.t

val update_password :
  Core.Ctx.t ->
  email:string ->
  old_password:string ->
  new_password:string ->
  (User_core.User.t, string) Result.t Lwt.t

val set_password :
  Core.Ctx.t ->
  user_id:string ->
  password:string ->
  (User_core.User.t, string) Result.t Lwt.t

val update_details :
  Core.Ctx.t ->
  email:string ->
  username:string option ->
  (User_core.User.t, string) Result.t Lwt.t

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
  Core.Ctx.t ->
  ?password_policy:(string -> (unit, string) Result.t) ->
  ?username:string ->
  email:string ->
  password:string ->
  password_confirmation:string ->
  unit ->
  ((User_core.User.t, string) Result.t, string) Result.t Lwt.t

val login :
  Core.Ctx.t ->
  email:string ->
  password:string ->
  ((User_core.User.t, string) Result.t, string) Result.t Lwt.t

val create_session_for :
  Core.Ctx.t -> User_core.User.t -> (unit, string) Result.t Lwt.t

val require_user : Core.Ctx.t -> (t, string) Result.t

val find_user : Core.Ctx.t -> t option
