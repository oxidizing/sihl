val to_sexp : Sihl_contract.User.t -> Sexplib0.Sexp.t
val to_yojson : Sihl_contract.User.t -> Yojson.Safe.t
val of_yojson : Yojson.Safe.t -> Sihl_contract.User.t option
val pp : Format.formatter -> Sihl_contract.User.t -> unit

val make
  :  email:string
  -> password:string
  -> username:string option
  -> admin:bool
  -> confirmed:bool
  -> (Sihl_contract.User.t, string) Result.t

val confirm : Sihl_contract.User.t -> Sihl_contract.User.t

val set_user_password
  :  Sihl_contract.User.t
  -> string
  -> (Sihl_contract.User.t, string) result

val set_user_details
  :  Sihl_contract.User.t
  -> email:string
  -> username:string option
  -> Sihl_contract.User.t

val is_admin : Sihl_contract.User.t -> bool
val is_owner : Sihl_contract.User.t -> string -> bool
val is_confirmed : Sihl_contract.User.t -> bool
val matches_password : string -> Sihl_contract.User.t -> bool
val default_password_policy : string -> (unit, string) result

val validate_new_password
  :  password:string
  -> password_confirmation:string
  -> password_policy:(string -> (unit, string) result)
  -> (unit, string) result

val validate_change_password
  :  Sihl_contract.User.t
  -> old_password:string
  -> new_password:string
  -> new_password_confirmation:string
  -> password_policy:(string -> (unit, string) result)
  -> (unit, string) result

include Sihl_contract.User.Sig

val lifecycle : unit -> Sihl_core.Container.Lifecycle.t
val register : (module Sihl_contract.User.Sig) -> Sihl_core.Container.Service.t
