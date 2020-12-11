open Sihl_contract.Session
open Sihl_core.Container

let instance : (module Sig) option ref = ref None

let set_value session ~k ~v =
  let module Service = (val unpack name instance : Sig) in
  Service.set_value session ~k ~v
;;

let find_value session key =
  let module Service = (val unpack name instance : Sig) in
  Service.find_value session key
;;

let create values =
  let module Service = (val unpack name instance : Sig) in
  Service.create values
;;

let find_opt key =
  let module Service = (val unpack name instance : Sig) in
  Service.find_opt key
;;

let find key =
  let module Service = (val unpack name instance : Sig) in
  Service.find key
;;

let find_all () =
  let module Service = (val unpack name instance : Sig) in
  Service.find_all ()
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
