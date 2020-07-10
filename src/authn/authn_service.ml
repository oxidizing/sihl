let ( let* ) = Lwt_result.bind

let key : (module Authn_sig.SERVICE) Core.Container.key =
  Core.Container.create_key "authn"

module AuthenticationService : Authn_sig.SERVICE = struct
  let on_bind _ =
    (* TODO register command *)
    Lwt.return @@ Ok ()

  let on_start _ = Lwt.return @@ Ok ()

  let on_stop _ = Lwt.return @@ Ok ()

  let find_user_in_session ctx =
    let* user_id = Session.get_value ctx ~key:"authn" in
    match user_id with
    | None -> Lwt_result.return None
    | Some user_id -> User.get ctx ~user_id

  let authenticate_session ctx user =
    Session.set_value ctx ~key:"authn" ~value:(User.id user)

  let unauthenticate_session ctx = Session.remove_value ctx ~key:"authn"
end

let service =
  Core.Container.create_binding key
    (module AuthenticationService)
    (module AuthenticationService)

let find_user_in_session ctx =
  let (module Service : Authn_sig.SERVICE) =
    Core.Container.fetch_service_exn key
  in
  Service.find_user_in_session ctx

let authenticate_session ctx =
  let (module Service : Authn_sig.SERVICE) =
    Core.Container.fetch_service_exn key
  in
  Service.authenticate_session ctx

let unauthenticate_sesssion ctx =
  let (module Service : Authn_sig.SERVICE) =
    Core.Container.fetch_service_exn key
  in
  Service.unauthenticate_session ctx
