open Sihl_contract.Queue
open Sihl_core.Container

let instance : (module Sig) option ref = ref None

let dispatch ~job ?delay input =
  let module Service = (val unpack name instance : Sig) in
  Service.dispatch ~job ?delay input
;;

let register_jobs jobs =
  let module Service = (val unpack name instance : Sig) in
  Service.register_jobs ~jobs
;;

let lifecycle () =
  let module Service = (val unpack name instance : Sig) in
  Service.lifecycle
;;

let register ?(jobs = []) implementation =
  let module Service = (val implementation : Sig) in
  instance := Some implementation;
  Service.register ~jobs ()
;;
