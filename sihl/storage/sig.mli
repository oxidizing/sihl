module Core = Sihl_core
module Repository = Sihl_repository
open Model

module type REPO = sig
  include Repository.Sig.REPO

  val insert_file : file:StoredFile.t -> unit Lwt.t
  val insert_blob : id:string -> blob:string -> unit Lwt.t
  val get_file : id:string -> StoredFile.t option Lwt.t
  val get_blob : id:string -> string option Lwt.t
  val update_file : file:StoredFile.t -> unit Lwt.t
  val update_blob : id:string -> blob:string -> unit Lwt.t
  val delete_file : id:string -> unit Lwt.t
  val delete_blob : id:string -> unit Lwt.t
end

module type SERVICE = sig
  include Core.Container.Service.Sig

  (** Get the meta data of a complete file.

      This will not download the content, use [get_data_base64] for that. *)
  val find_opt : id:string -> StoredFile.t option Lwt.t

  val find : id:string -> StoredFile.t Lwt.t
  val delete : id:string -> unit Lwt.t

  (** Upload base64 string as data content for [file]. *)
  val upload_base64 : file:File.t -> base64:string -> StoredFile.t Lwt.t

  (** Upload and overwrite base64 strong content of [file]. *)
  val update_base64 : file:StoredFile.t -> base64:string -> StoredFile.t Lwt.t

  (** Download actual file content for [file]. *)
  val download_data_base64_opt : file:StoredFile.t -> string option Lwt.t

  val download_data_base64 : file:StoredFile.t -> string Lwt.t
  val register : unit -> Core.Container.Service.t
end
