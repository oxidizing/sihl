include Sihl_contract.Token.Sig

val lifecycle : unit -> Sihl_core.Container.lifecycle
val register : (module Sihl_contract.Token.Sig) -> Sihl_core.Container.Service.t
