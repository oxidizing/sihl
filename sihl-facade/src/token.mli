include Sihl_contract.Token.Sig

val lifecycle : unit -> Sihl_core.Container.Lifecycle.t
val register : (module Sihl_contract.Token.Sig) -> Sihl_core.Container.Service.t
