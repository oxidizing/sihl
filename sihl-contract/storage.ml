open Sihl_type

exception Exception of string

module type Sig = sig
  include Sihl_core.Container.Service.Sig

  (** Get the meta data of a complete file.

      This will not download the content, use [get_data_base64] for that. *)
  val find_opt : id:string -> Storage_stored.t option Lwt.t

  val find : id:string -> Storage_stored.t Lwt.t
  val delete : id:string -> unit Lwt.t

  (** Upload base64 string as data content for [file]. *)
  val upload_base64 : file:Storage_file.t -> base64:string -> Storage_stored.t Lwt.t

  (** Upload and overwrite base64 strong content of [file]. *)
  val update_base64 : file:Storage_stored.t -> base64:string -> Storage_stored.t Lwt.t

  (** Download actual file content for [file]. *)
  val download_data_base64_opt : file:Storage_stored.t -> string option Lwt.t

  val download_data_base64 : file:Storage_stored.t -> string Lwt.t
  val register : unit -> Sihl_core.Container.Service.t
end
