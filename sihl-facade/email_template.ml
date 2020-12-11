open Sihl_contract.Email_template
open Sihl_core.Container

let instance : (module Sig) option ref = ref None

let get ~id =
  let module Service = (val unpack name instance : Sig) in
  Service.get ~id
;;

let get_by_name ~name =
  let module Service = (val unpack name instance : Sig) in
  Service.get_by_name ~name
;;

let create ~name ~html ~text =
  let module Service = (val unpack name instance : Sig) in
  Service.create ~name ~html ~text
;;

let update ~template =
  let module Service = (val unpack name instance : Sig) in
  Service.update ~template
;;

let render email =
  let module Service = (val unpack name instance : Sig) in
  Service.render email
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
