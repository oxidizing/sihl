open Sihl_contract.Random
open Sihl_core.Container

let instance : (module Sig) option ref = ref None

let bytes ~nr =
  let module Service = (val unpack name instance : Sig) in
  Service.bytes ~nr
;;

let base64 ~nr =
  let module Service = (val unpack name instance : Sig) in
  Service.base64 ~nr
;;
