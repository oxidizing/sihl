open Sihl_contract.Storage
open Sihl_core.Container

let file_to_sexp { id; filename; filesize; mime } =
  let open Sexplib0.Sexp_conv in
  let open Sexplib0.Sexp in
  List
    [ List [ Atom "id"; sexp_of_string id ]
    ; List [ Atom "filename"; sexp_of_string filename ]
    ; List [ Atom "filesize"; sexp_of_int filesize ]
    ; List [ Atom "mime"; sexp_of_string mime ]
    ]
;;

let pp_file fmt t = Sexplib0.Sexp.pp_hum fmt (file_to_sexp t)
let set_mime mime file = { file with mime }
let set_filesize filesize file = { file with filesize }
let set_filename filename file = { file with filename }

let set_mime_stored mime stored_file =
  { stored_file with file = set_mime mime stored_file.file }
;;

let set_filesize_stored size stored_file =
  { stored_file with file = set_filesize size stored_file.file }
;;

let set_filename_stored name stored_file =
  { stored_file with file = set_filename name stored_file.file }
;;

let stored_to_sexp { file; _ } =
  let open Sexplib0.Sexp_conv in
  let open Sexplib0.Sexp in
  List
    [ List [ Atom "file"; file_to_sexp file ]
    ; List [ Atom "blob"; sexp_of_string "<binary>" ]
    ]
;;

let pp_stored fmt t = Sexplib0.Sexp.pp_hum fmt (stored_to_sexp t)

(* Service *)

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

let upload_base64 file ~base64 =
  let module Service = (val unpack name instance : Sig) in
  Service.upload_base64 file ~base64
;;

let update_base64 file ~base64 =
  let module Service = (val unpack name instance : Sig) in
  Service.update_base64 file ~base64
;;

let download_data_base64_opt file =
  let module Service = (val unpack name instance : Sig) in
  Service.download_data_base64_opt file
;;

let download_data_base64 file =
  let module Service = (val unpack name instance : Sig) in
  Service.download_data_base64 file
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
