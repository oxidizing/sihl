val to_sexp : Sihl_contract.Session.t -> Sexplib0.Sexp.t
val pp : Format.formatter -> Sihl_contract.Session.t -> unit
val expiration_date : Ptime.t -> Ptime.t
val key : Sihl_contract.Session.t -> string
val is_expired : Ptime.t -> Sihl_contract.Session.t -> bool

val set_value
  :  Sihl_contract.Session.t
  -> k:string
  -> v:string option
  -> unit Lwt.t

val find_value : Sihl_contract.Session.t -> string -> string option Lwt.t
val create : (string * string) list -> Sihl_contract.Session.t Lwt.t
val find_opt : string -> Sihl_contract.Session.t option Lwt.t
val find : string -> Sihl_contract.Session.t Lwt.t
val find_all : unit -> Sihl_contract.Session.t list Lwt.t
val lifecycle : unit -> Sihl_core.Container.Lifecycle.t

val register
  :  (module Sihl_contract.Session.Sig)
  -> Sihl_core.Container.Service.t
