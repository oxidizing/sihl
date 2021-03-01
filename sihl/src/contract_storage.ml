type file =
  { id : string
  ; filename : string
  ; filesize : int
  ; mime : string
  }

type stored =
  { file : file
  ; blob : string
  }

let name = "storage"

exception Exception of string

module type Sig = sig
  (** Get the meta data of a complete file.

      This will not download the content, use [get_data_base64] for that. *)
  val find_opt : id:string -> stored option Lwt.t

  val find : id:string -> stored Lwt.t
  val delete : id:string -> unit Lwt.t

  (** Upload base64 string as data content for [file]. *)
  val upload_base64 : file -> base64:string -> stored Lwt.t

  (** Upload and overwrite base64 strong content of [file]. *)
  val update_base64 : stored -> base64:string -> stored Lwt.t

  (** Download actual file content for [file]. *)
  val download_data_base64_opt : stored -> string option Lwt.t

  val download_data_base64 : stored -> string Lwt.t
  val register : unit -> Core_container.Service.t

  include Core_container.Service.Sig
end

(* Common *)

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
