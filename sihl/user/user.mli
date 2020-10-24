(** This module provides the abstraction of a user that interacts with the Sihl ap. Use it
    to register new users, changes password, reset passwords and update user details.

    User handling is a common task in web development, so Sihl comes with a minimal user
    model [Sihl.User.t]. Typically you need some kind of domain user, like a customer that
    has pizza orders assigned or a applicant that submits applications. This is something
    that you implement while referencing to {!Sihl.User.t}. *)

(** {1 Installation}

    [{ module Repo = Sihl.Data.Repo.Service.Make () module Cmd = Sihl.Cmd.Service.Make ()
    module Log = Sihl.Log.Service.Make () module Db = Sihl.Database.Service (Config) (Log)
    module MigrationRepo = Sihl.Data.Migration.Service.Repo.MakeMariaDb (Db) module
    Migration = Sihl.Data.Migration.Service.Make (Log) (Cmd) (Db) (MigrationRepo) }] *)

module Authz = Authz
module Seed = Seed

type t = Model.t

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
val confirm : t -> t
val set_user_password : t -> string -> (t, string) Result.t
val set_user_details : t -> email:string -> username:string option -> t
val is_admin : t -> bool
val is_owner : t -> string -> bool
val is_confirmed : t -> bool
val matches_password : string -> t -> bool
val sexp_of_t : t -> Sexplib.Sexp.t

val validate_new_password
  :  password:string
  -> password_confirmation:string
  -> password_policy:(string -> (unit, string) Result.t)
  -> (unit, string) Result.t

val validate_change_password
  :  t
  -> old_password:string
  -> new_password:string
  -> new_password_confirmation:string
  -> password_policy:(string -> (unit, string) Result.t)
  -> (unit, string) Result.t

val t : t Caqti_type.t

(** {1 Usage} *)

module Service = Service
module Repo = Repo
module Sig = Sig
