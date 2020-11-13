open Lwt.Syntax
module Core = Sihl_core
module Session = Sihl_session
module User = Sihl_user

exception Exception of string

let log_src = Logs.Src.create ~doc:"authn" "sihl.service.authn"

module Logs = (val Logs.src_log log_src : Logs.LOG)

module Make (SessionService : Session.Sig.SERVICE) (UserService : User.Sig.SERVICE) :
  Sig.SERVICE = struct
  let find_user_in_session_opt session =
    let* user_id = SessionService.get session ~key:"authn" in
    match user_id with
    | None -> Lwt.return None
    | Some user_id -> UserService.find_opt ~user_id
  ;;

  let find_user_in_session session =
    let* user_id = SessionService.get session ~key:"authn" in
    match user_id with
    | None -> raise @@ Exception "No user found in current session"
    | Some user_id -> UserService.find ~user_id
  ;;

  let authenticate_session user session =
    SessionService.set session ~key:"authn" ~value:(User.id user)
  ;;

  let unauthenticate_session session = SessionService.unset session ~key:"authn"
  let start () = Lwt.return ()
  let stop _ = Lwt.return ()

  let lifecycle =
    Core.Container.Lifecycle.create
      "authn"
      ~start
      ~stop
      ~dependencies:[ SessionService.lifecycle; UserService.lifecycle ]
  ;;

  let register () = Core.Container.Service.create lifecycle
end
