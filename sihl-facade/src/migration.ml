open Sihl_contract.Migration
open Sihl_core.Container

let to_sexp (namespace, steps) =
  let open Sexplib0.Sexp_conv in
  let open Sexplib0.Sexp in
  let steps =
    List.map
      (fun { label; statement; check_fk } ->
        List
          [ List [ Atom "label"; sexp_of_string label ]
          ; List [ Atom "statement"; sexp_of_string statement ]
          ; List [ Atom "check_fk"; sexp_of_bool check_fk ]
          ])
      steps
  in
  List (List.cons (List [ Atom "namespace"; sexp_of_string namespace ]) steps)
;;

let pp fmt t = Sexplib0.Sexp.pp_hum fmt (to_sexp t)
let empty namespace = namespace, []

let create_step ~label ?(check_fk = true) statement =
  { label; check_fk; statement }
;;

(* Append the migration step to the list of steps *)
let add_step step (label, steps) = label, List.concat [ steps; [ step ] ]

(* Service *)

let instance : (module Sig) option ref = ref None

let execute migrations =
  let module Service = (val unpack name instance : Sig) in
  Service.execute migrations
;;

let register_migrations migrations =
  let module Service = (val unpack name instance : Sig) in
  Service.register_migrations migrations
;;

let register_migration migration =
  let module Service = (val unpack name instance : Sig) in
  Service.register_migration migration
;;

let run_all () =
  let module Service = (val unpack name instance : Sig) in
  Service.run_all ()
;;

let lifecycle () =
  let module Service = (val Sihl_core.Container.unpack name instance : Sig) in
  Service.lifecycle
;;

let register ?migrations implementation =
  let module Service = (val implementation : Sig) in
  instance := Some implementation;
  Service.register ?migrations ()
;;
