open Sihl_contract.Queue
open Sihl_core.Container

let to_sexp { name; max_tries; retry_delay; _ } =
  let open Sexplib0.Sexp_conv in
  let open Sexplib0.Sexp in
  List
    [ List [ Atom "name"; sexp_of_string name ]
    ; List [ Atom "max_tries"; sexp_of_int max_tries ]
    ; List
        [ Atom "retry_delay"
        ; sexp_of_string (Sihl_core.Time.show_duration retry_delay)
        ]
    ]
;;

let pp fmt t = Sexplib0.Sexp.pp_hum fmt (to_sexp t)
let default_tries = 5
let default_retry_delay = Sihl_core.Time.OneMinute

let create ~name ~input_to_string ~string_to_input ~handle ?failed () =
  let failed =
    failed |> Option.value ~default:(fun _ -> Lwt_result.return ())
  in
  { name
  ; input_to_string
  ; string_to_input
  ; handle
  ; failed
  ; max_tries = default_tries
  ; retry_delay = default_retry_delay
  }
;;

let set_max_tries max_tries job = { job with max_tries }
let set_retry_delay retry_delay job = { job with retry_delay }

(* Service *)
let instance : (module Sig) option ref = ref None

let dispatch job ?delay input =
  let module Service = (val unpack name instance : Sig) in
  Service.dispatch job ?delay input
;;

let register_jobs jobs =
  let module Service = (val unpack name instance : Sig) in
  Service.register_jobs jobs
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
