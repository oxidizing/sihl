open Sihl_contract.Migration
open Sihl_core.Container

let instance : (module Sig) option ref = ref None

let execute migrations =
  let module Service = (val unpack name instance : Sig) in
  Service.execute migrations
;;

let run_all () =
  let module Service = (val unpack name instance : Sig) in
  Service.run_all ()
;;

let register implementation =
  let module Service = (val implementation : Sig) in
  instance := Some implementation;
  Service.register ()
;;
