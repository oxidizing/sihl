(** This module provides the abstraction of a user that interacts with the Sihl ap. Use it to register new users, changes password, reset passwords and update user details.

*)

module Authz = User_authz
module Service = User_service
module Seed = User_seed
module PasswordReset = User_password_reset

type t = User_core.User.t

val confirmed : t -> bool

val admin : t -> bool

val status : t -> string

val password : t -> string

val username : t -> string option

val email : t -> string

val id : t -> string

val created_at : t -> Ptime.t

val to_yojson : t -> Yojson.Safe.t

val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

val pp : Caml.Format.formatter -> t -> unit

val show : t -> string

val equal : t -> t -> bool

val alcotest : t Alcotest.testable

val confirm : t -> t

val set_user_password : t -> string -> (t, string) Result.t

val set_user_details : t -> email:string -> username:string option -> t

val is_admin : t -> bool

val is_owner : t -> string -> bool

val is_confirmed : t -> bool

val matches_password : string -> t -> bool

val validate_new_password :
  password:string ->
  password_confirmation:string ->
  password_policy:(string -> (unit, string) Result.t) ->
  (unit, string) Result.t

val validate_change_password :
  t ->
  old_password:string ->
  new_password:string ->
  new_password_confirmation:string ->
  password_policy:(string -> (unit, string) Result.t) ->
  (unit, string) Result.t

val t : t Caqti_type.t
