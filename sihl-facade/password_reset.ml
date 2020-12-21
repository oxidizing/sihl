open Sihl_contract.Password_reset
open Sihl_core.Container

let instance : (module Sig) option ref = ref None

let create_reset_token ~email =
  let module Service = (val unpack name instance : Sig) in
  Service.create_reset_token ~email
;;

let reset_password ~token ~password ~password_confirmation =
  let module Service = (val unpack name instance : Sig) in
  Service.reset_password ~token ~password ~password_confirmation
;;

let lifecycle () =
  let module Service = (val unpack name instance : Sig) in
  Service.lifecycle
;;

let register implementation =
  let module Service = (val implementation : Sig) in
  instance := Some implementation;
  Service.register ()
;;
