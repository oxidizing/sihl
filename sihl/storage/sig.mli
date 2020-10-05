open Model

module type REPO = sig
  include Repository.Sig.REPO
  module DatabaseService : Database.Sig.SERVICE

  val insert_file : Core.Ctx.t -> file:StoredFile.t -> unit Lwt.t
  val insert_blob : Core.Ctx.t -> id:string -> blob:string -> unit Lwt.t
  val get_file : Core.Ctx.t -> id:string -> StoredFile.t option Lwt.t
  val get_blob : Core.Ctx.t -> id:string -> string option Lwt.t
  val update_file : Core.Ctx.t -> file:StoredFile.t -> unit Lwt.t
  val update_blob : Core.Ctx.t -> id:string -> blob:string -> unit Lwt.t
  val delete_file : Core.Ctx.t -> id:string -> unit Lwt.t
  val delete_blob : Core.Ctx.t -> id:string -> unit Lwt.t
end

module type SERVICE = sig
  include Core.Container.Service.Sig

  (** Get the meta data of a complete file.

      This will not download the content, use [get_data_base64] for that. *)
  val find_opt : Core.Ctx.t -> id:string -> StoredFile.t option Lwt.t

  val find : Core.Ctx.t -> id:string -> StoredFile.t Lwt.t
  val delete : Core.Ctx.t -> id:string -> unit Lwt.t

  (** Upload base64 string as data content for [file]. *)
  val upload_base64 : Core.Ctx.t -> file:File.t -> base64:string -> StoredFile.t Lwt.t

  (** Upload and overwrite base64 strong content of [file]. *)
  val update_base64
    :  Core.Ctx.t
    -> file:StoredFile.t
    -> base64:string
    -> StoredFile.t Lwt.t

  (** Download actual file content for [file]. *)
  val download_data_base64_opt : Core.Ctx.t -> file:StoredFile.t -> string option Lwt.t

  val download_data_base64 : Core.Ctx.t -> file:StoredFile.t -> string Lwt.t
  val configure : Core.Configuration.data -> Core.Container.Service.t
end
