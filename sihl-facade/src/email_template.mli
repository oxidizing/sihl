val to_sexp : Sihl_contract.Email_template.t -> Sexplib0.Sexp.t
val to_yojson : Sihl_contract.Email_template.t -> Yojson.Safe.t
val of_yojson : Yojson.Safe.t -> Sihl_contract.Email_template.t option
val pp : Format.formatter -> Sihl_contract.Email_template.t -> unit

val set_label
  :  string
  -> Sihl_contract.Email_template.t
  -> Sihl_contract.Email_template.t

val set_text
  :  string
  -> Sihl_contract.Email_template.t
  -> Sihl_contract.Email_template.t

val set_html
  :  string option
  -> Sihl_contract.Email_template.t
  -> Sihl_contract.Email_template.t

val replace_element : string -> string -> string -> string

val render
  :  (string * string) list
  -> string
  -> string option
  -> string * string option

val email_of_template
  :  ?template:Sihl_contract.Email_template.t
  -> Sihl_contract.Email.t
  -> (string * string) list
  -> Sihl_contract.Email.t Lwt.t

include Sihl_contract.Email_template.Sig

val lifecycle : unit -> Sihl_core.Container.Lifecycle.t

val register
  :  (module Sihl_contract.Email_template.Sig)
  -> Sihl_core.Container.Service.t
