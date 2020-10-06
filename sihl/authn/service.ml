open Lwt.Syntax

exception Exception of string

module Make (SessionService : Session.Sig.SERVICE) (UserService : User.Sig.SERVICE) :
  Sig.SERVICE = struct
  let find_user_in_session_opt ctx =
    let* user_id = SessionService.get ctx ~key:"authn" in
    match user_id with
    | None -> Lwt.return None
    | Some user_id -> UserService.find_opt ctx ~user_id
  ;;

  let find_user_in_session ctx =
    let* user_id = SessionService.get ctx ~key:"authn" in
    match user_id with
    | None -> raise @@ Exception "No user found in current session"
    | Some user_id -> UserService.find ctx ~user_id
  ;;

  let authenticate_session ctx user =
    SessionService.set ctx ~key:"authn" ~value:(User.id user)
  ;;

  let unauthenticate_session ctx = SessionService.unset ctx ~key:"authn"
  let start ctx = Lwt.return ctx
  let stop _ = Lwt.return ()

  let lifecycle =
    Core.Container.Lifecycle.create
      "authn"
      ~start
      ~stop
      ~dependencies:[ SessionService.lifecycle; UserService.lifecycle ]
  ;;

  let configure configuration =
    let configuration = Core.Configuration.make configuration in
    Core.Container.Service.create ~configuration lifecycle
  ;;
end
