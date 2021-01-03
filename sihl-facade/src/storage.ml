open Sihl_contract.Storage
open Sihl_core.Container

let instance : (module Sig) option ref = ref None

let find_opt ~id =
  let module Service = (val unpack name instance : Sig) in
  Service.find_opt ~id
;;

let find ~id =
  let module Service = (val unpack name instance : Sig) in
  Service.find ~id
;;

let delete ~id =
  let module Service = (val unpack name instance : Sig) in
  Service.delete ~id
;;

let upload_base64 ~file ~base64 =
  let module Service = (val unpack name instance : Sig) in
  Service.upload_base64 ~file ~base64
;;

let update_base64 ~file ~base64 =
  let module Service = (val unpack name instance : Sig) in
  Service.update_base64 ~file ~base64
;;

let download_data_base64_opt ~file =
  let module Service = (val unpack name instance : Sig) in
  Service.download_data_base64_opt ~file
;;

let download_data_base64 ~file =
  let module Service = (val unpack name instance : Sig) in
  Service.download_data_base64 ~file
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
