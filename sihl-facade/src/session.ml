open Sihl_contract.Session
open Sihl_core.Container

let to_sexp { key; expire_date; _ } =
  let open Sexplib0.Sexp_conv in
  let open Sexplib0.Sexp in
  List
    [ List [ Atom "key"; sexp_of_string key ]
    ; List [ Atom "expire_date"; sexp_of_string (Ptime.to_rfc3339 expire_date) ]
    ]
;;

let pp fmt t = Sexplib0.Sexp.pp_hum fmt (to_sexp t)

let expiration_date now =
  Sihl_core.Time.date_from_now now Sihl_core.Time.OneWeek
;;

let key session = session.key
let is_expired now session = Ptime.is_later now ~than:session.expire_date

(* Service *)

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
