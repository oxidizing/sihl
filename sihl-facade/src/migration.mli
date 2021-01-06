val to_sexp : Sihl_contract.Migration.t -> Sexplib0.Sexp.t
val pp : Format.formatter -> Sihl_contract.Migration.t -> unit
val empty : string -> Sihl_contract.Migration.t

val create_step
  :  label:string
  -> ?check_fk:bool
  -> string
  -> Sihl_contract.Migration.step

val add_step
  :  Sihl_contract.Migration.step
  -> Sihl_contract.Migration.t
  -> Sihl_contract.Migration.t

include Sihl_contract.Migration.Sig

val lifecycle : unit -> Sihl_core.Container.Lifecycle.t

val register
  :  ?migrations:Sihl_contract.Migration.t list
  -> (module Sihl_contract.Migration.Sig)
  -> Sihl_core.Container.Service.t
