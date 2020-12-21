open Sihl_contract.Authn
open Sihl_core.Container

let instance : (module Sig) option ref = ref None

let find_user_in_session_opt session =
  let module Service = (val unpack name instance : Sig) in
  Service.find_user_in_session_opt session
;;

let find_user_in_session session =
  let module Service = (val unpack name instance : Sig) in
  Service.find_user_in_session session
;;

let authenticate_session user session =
  let module Service = (val unpack name instance : Sig) in
  Service.authenticate_session user session
;;

let unauthenticate_session session =
  let module Service = (val unpack name instance : Sig) in
  Service.unauthenticate_session session
;;

let register implementation =
  let module Service = (val implementation : Sig) in
  instance := Some implementation;
  Service.register ()
;;
