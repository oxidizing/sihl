open Sihl_contract.Token
open Sihl_core.Container

let instance : (module Sig) option ref = ref None

let create ?secret ?expires_in data =
  let module Service = (val unpack name instance : Sig) in
  Service.create ?secret ?expires_in data
;;

let read ?secret ?force token ~k =
  let module Service = (val unpack name instance : Sig) in
  Service.read ?secret ?force token ~k
;;

let read_all ?secret ?force token =
  let module Service = (val unpack name instance : Sig) in
  Service.read_all ?secret ?force token
;;

let verify ?secret token =
  let module Service = (val unpack name instance : Sig) in
  Service.verify ?secret token
;;

let deactivate token =
  let module Service = (val unpack name instance : Sig) in
  Service.deactivate token
;;

let activate token =
  let module Service = (val unpack name instance : Sig) in
  Service.activate token
;;

let is_active token =
  let module Service = (val unpack name instance : Sig) in
  Service.is_active token
;;

let is_expired ?secret token =
  let module Service = (val unpack name instance : Sig) in
  Service.is_expired ?secret token
;;

let is_valid ?secret token =
  let module Service = (val unpack name instance : Sig) in
  Service.is_valid ?secret token
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
