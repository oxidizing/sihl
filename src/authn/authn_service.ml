let key : (module Authn_sig.SERVICE) Core.Container.key =
  Core.Container.create_key "authn.service"

module AuthenticationService : Authn_sig.SERVICE = struct
  let on_bind _ =
    (* TODO register command *)
    Lwt.return @@ Ok ()

  let on_start _ = Lwt.return @@ Ok ()

  let on_stop _ = Lwt.return @@ Ok ()

  let authenticate = failwith "TODO"
end

let service =
  Core.Container.create_binding key
    (module AuthenticationService)
    (module AuthenticationService)
