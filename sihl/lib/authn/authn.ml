module Service = struct
  let key = Authn_service.key

  module type SERVICE = Authn_sig.SERVICE
end

let authenticate req =
  let (module Service : Service.SERVICE) =
    Core.Container.fetch_exn Authn_service.key
  in
  Service.authenticate req
