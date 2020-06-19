module type AUTHN_SERVICE = sig
  val authenticate : Opium_kernel.Request.t -> User.t
end

let registry_key = Core.Container.Key.create "/authn/service"

let authenticate req =
  let (module Service : AUTHN_SERVICE) =
    Core.Container.fetch_exn registry_key
  in
  Service.authenticate req
