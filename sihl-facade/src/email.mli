val to_sexp : Sihl_contract.Email.t -> Sexplib0.Sexp.t
val to_yojson : Sihl_contract.Email.t -> Yojson.Safe.t
val of_yojson : Yojson.Safe.t -> Sihl_contract.Email.t option
val pp : Format.formatter -> Sihl_contract.Email.t -> unit
val set_text : string -> Sihl_contract.Email.t -> Sihl_contract.Email.t
val set_html : string option -> Sihl_contract.Email.t -> Sihl_contract.Email.t

val create
  :  ?html:string
  -> ?cc:string list
  -> ?bcc:string list
  -> sender:string
  -> recipient:string
  -> subject:string
  -> string
  -> Sihl_contract.Email.t

include Sihl_contract.Email.Sig

val lifecycle : unit -> Sihl_core.Container.Lifecycle.t
val register : (module Sihl_contract.Email.Sig) -> Sihl_core.Container.Service.t
