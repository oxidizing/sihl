let ( let* ) = Lwt_result.bind

module Make
    (SessionService : Session.Sig.SERVICE)
    (UserService : User.Sig.SERVICE) : Authn_sig.SERVICE = struct
  let lifecycle =
    Core.Container.Lifecycle.make "authn"
      ~dependencies:[ SessionService.lifecycle; UserService.lifecycle ]
      (fun ctx -> Lwt.return ctx)
      (fun _ -> Lwt.return ())

  let find_user_in_session ctx =
    let* user_id = SessionService.get_value ctx ~key:"authn" in
    match user_id with
    | None -> Lwt_result.return None
    | Some user_id -> UserService.get ctx ~user_id

  let authenticate_session ctx user =
    SessionService.set_value ctx ~key:"authn" ~value:(User.id user)

  let unauthenticate_session ctx = SessionService.remove_value ctx ~key:"authn"
end
