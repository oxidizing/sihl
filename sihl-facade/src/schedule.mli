include Sihl_contract.Schedule.Sig

val lifecycle : unit -> Sihl_core.Container.lifecycle

val register
  :  (module Sihl_contract.Schedule.Sig)
  -> Sihl_core.Container.Service.t list
