open Sihl_contract.Email
open Sihl_core.Container

let instance : (module Sig) option ref = ref None

let send email =
  let module Service = (val unpack name instance : Sig) in
  Service.send email
;;

let bulk_send emails =
  let module Service = (val unpack name instance : Sig) in
  Service.bulk_send emails
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
