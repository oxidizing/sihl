module type AUTHN_SERVICE = sig
  val authenticate : Opium_kernel.Request.t -> User.t
end

let registry_key = Core.Registry.Key.create "/authn/service"

let authenticate req =
  let (module Service : AUTHN_SERVICE) = Core.Registry.fetch_exn registry_key in
  Service.authenticate req
