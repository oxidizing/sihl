open Sihl_contract.Random

let instance : (module Sig) ref = ref (module Sihl_core.Random : Sig)

let bytes ~nr =
  let module Service = (val !instance : Sig) in
  Service.bytes ~nr
;;

let base64 ~nr =
  let module Service = (val !instance : Sig) in
  Service.base64 ~nr
;;