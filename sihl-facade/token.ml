open Sihl_contract.Token
open Sihl_core.Container

let instance : (module Sig) option ref = ref None

let create ~kind ?data ?expires_in ?length () =
  let module Service = (val unpack name instance : Sig) in
  Service.create ~kind ?data ?expires_in ?length ()
;;

let find str =
  let module Service = (val unpack name instance : Sig) in
  Service.find str
;;

let find_opt str =
  let module Service = (val unpack name instance : Sig) in
  Service.find_opt str
;;

let find_by_id id =
  let module Service = (val unpack name instance : Sig) in
  Service.find_opt id
;;

let find_by_id_opt id =
  let module Service = (val unpack name instance : Sig) in
  Service.find_by_id_opt id
;;

let invalidate token =
  let module Service = (val unpack name instance : Sig) in
  Service.invalidate token
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
