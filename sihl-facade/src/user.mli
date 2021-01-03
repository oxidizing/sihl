type t = Sihl_contract.User.t

val to_yojson : t -> Yojson.Safe.t
val of_yojson : Yojson.Safe.t -> t option
val pp : Format.formatter -> t -> unit

val make
  :  email:string
  -> password:string
  -> username:string option
  -> admin:bool
  -> confirmed:bool
  -> (t, string) Result.t

val sexp_of_t : t -> Sexplib0.Sexp.t
val confirm : t -> t
val set_user_password : t -> string -> (t, string) result
val set_user_details : t -> email:string -> username:string option -> t
val is_admin : t -> bool
val is_owner : t -> string -> bool
val is_confirmed : t -> bool
val matches_password : string -> t -> bool
val default_password_policy : string -> (unit, string) result

val validate_new_password
  :  password:string
  -> password_confirmation:string
  -> password_policy:(string -> (unit, string) result)
  -> (unit, string) result

val validate_change_password
  :  t
  -> old_password:string
  -> new_password:string
  -> new_password_confirmation:string
  -> password_policy:(string -> (unit, string) result)
  -> (unit, string) result

include Sihl_contract.User.Sig

val lifecycle : unit -> Sihl_core.Container.Lifecycle.t
val register : (module Sihl_contract.User.Sig) -> Sihl_core.Container.Service.t

module Seed : sig
  val admin : email:string -> password:string -> t Lwt.t
  val user : email:string -> password:string -> ?username:string -> unit -> t Lwt.t
end
