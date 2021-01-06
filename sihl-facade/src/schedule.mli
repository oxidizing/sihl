include Sihl_contract.Schedule.Sig

val lifecycle : unit -> Sihl_core.Container.Lifecycle.t

val register
  :  (module Sihl_contract.Schedule.Sig)
  -> Sihl_core.Container.Service.t
