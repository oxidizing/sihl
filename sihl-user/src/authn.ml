open Lwt.Syntax
module Core = Sihl_core
module Session = Sihl_contract.Session
module User = Sihl_contract.User

let log_src = Logs.Src.create ~doc:"authn" "sihl.service.authn"

module Logs = (val Logs.src_log log_src : Logs.LOG)

let find_user_in_session_opt session =
  let* user_id = Sihl_facade.Session.find_value session "authn" in
  match user_id with
  | None -> Lwt.return None
  | Some user_id -> Sihl_facade.User.find_opt ~user_id
;;

let find_user_in_session session =
  let* user_id = Sihl_facade.Session.find_value session "authn" in
  match user_id with
  | None -> raise @@ Sihl_contract.Authn.Exception "No user found in current session"
  | Some user_id -> Sihl_facade.User.find ~user_id
;;

let authenticate_session user session =
  Sihl_facade.Session.set_value session ~k:"authn" ~v:(Some (User.id user))
;;

let unauthenticate_session session =
  Sihl_facade.Session.set_value session ~k:"authn" ~v:None
;;

let start () = Lwt.return ()
let stop () = Lwt.return ()

let lifecycle =
  Core.Container.Lifecycle.create "authn" ~start ~stop ~dependencies:(fun () ->
      [ Sihl_facade.Session.lifecycle (); Sihl_facade.User.lifecycle () ])
;;

let register () =
  (* TODO [jerben] register session and user service *)
  Core.Container.Service.create lifecycle
;;
