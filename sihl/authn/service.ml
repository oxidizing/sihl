open Lwt.Syntax

exception Exception of string

let log_src = Logs.Src.create ~doc:"authn" "sihl.service.authn"

module Logs = (val Logs.src_log log_src : Logs.LOG)

module Make (SessionService : Session.Sig.SERVICE) (UserService : User.Sig.SERVICE) :
  Sig.SERVICE = struct
  let find_user_in_session_opt ctx session =
    let* user_id = SessionService.get ctx session ~key:"authn" in
    match user_id with
    | None -> Lwt.return None
    | Some user_id -> UserService.find_opt ctx ~user_id
  ;;

  let find_user_in_session ctx session =
    let* user_id = SessionService.get ctx session ~key:"authn" in
    match user_id with
    | None -> raise @@ Exception "No user found in current session"
    | Some user_id -> UserService.find ctx ~user_id
  ;;

  let authenticate_session ctx user session =
    SessionService.set ctx session ~key:"authn" ~value:(User.id user)
  ;;

  let unauthenticate_session ctx session = SessionService.unset ctx session ~key:"authn"
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
