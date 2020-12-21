module File = struct
  type t =
    { id : string
    ; filename : string
    ; filesize : int
    ; mime : string
    }
  [@@deriving fields, yojson, show, eq, make]

  let set_mime mime file = { file with mime }
  let set_filesize filesize file = { file with filesize }
  let set_filename filename file = { file with filename }
end

module Stored = struct
  type t =
    { file : File.t
    ; blob : string
    }
  [@@deriving fields, yojson, show, eq, make]

  let mime stored_file = File.mime stored_file.file
  let filesize stored_file = File.filesize stored_file.file
  let filename stored_file = File.filename stored_file.file

  let set_mime mime stored_file =
    { stored_file with file = File.set_mime mime stored_file.file }
  ;;

  let set_filesize size stored_file =
    { stored_file with file = File.set_filesize size stored_file.file }
  ;;

  let set_filename name stored_file =
    { stored_file with file = File.set_filename name stored_file.file }
  ;;
end

(* Signature *)

let name = "sihl.service.storage"

exception Exception of string

module type Sig = sig
  include Sihl_core.Container.Service.Sig

  (** Get the meta data of a complete file.

      This will not download the content, use [get_data_base64] for that. *)
  val find_opt : id:string -> Stored.t option Lwt.t

  val find : id:string -> Stored.t Lwt.t
  val delete : id:string -> unit Lwt.t

  (** Upload base64 string as data content for [file]. *)
  val upload_base64 : file:File.t -> base64:string -> Stored.t Lwt.t

  (** Upload and overwrite base64 strong content of [file]. *)
  val update_base64 : file:Stored.t -> base64:string -> Stored.t Lwt.t

  (** Download actual file content for [file]. *)
  val download_data_base64_opt : file:Stored.t -> string option Lwt.t

  val download_data_base64 : file:Stored.t -> string Lwt.t
  val register : unit -> Sihl_core.Container.Service.t
end
