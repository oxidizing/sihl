open Sihl_contract.Schedule
open Sihl_core.Container

let instance : (module Sig) option ref = ref None

let schedule schedule =
  let module Service = (val unpack name instance : Sig) in
  Service.schedule schedule
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
