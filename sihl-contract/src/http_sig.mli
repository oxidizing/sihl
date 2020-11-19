include Sihl_core.Container.Service.Sig

val register : ?routers:Http_route.router list -> unit -> Sihl_core.Container.Service.t
