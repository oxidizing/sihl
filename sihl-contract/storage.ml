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
  include Sihl_core.Container.Service.Sig

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
  val register : unit -> Sihl_core.Container.Service.t
end
