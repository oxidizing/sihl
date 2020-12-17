open Sihl_contract.Http
open Sihl_core.Container

let instance : (module Sig) option ref = ref None

let lifecycle () =
  let module Service = (val unpack name instance : Sig) in
  Service.lifecycle
;;

let register implementation =
  let module Service = (val implementation : Sig) in
  instance := Some implementation;
  Service.register ()
;;
