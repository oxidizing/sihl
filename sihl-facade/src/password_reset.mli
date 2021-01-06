include Sihl_contract.Password_reset.Sig

val lifecycle : unit -> Sihl_core.Container.Lifecycle.t

val register
  :  (module Sihl_contract.Password_reset.Sig)
  -> Sihl_core.Container.Service.t
