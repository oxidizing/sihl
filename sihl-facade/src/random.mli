include Sihl_contract.Random.Sig

val lifecycle : unit -> Sihl_core.Container.Lifecycle.t

val register
  :  (module Sihl_contract.Random.Sig)
  -> Sihl_core.Container.Service.t
