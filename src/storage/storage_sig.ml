open Storage_model

module type REPO = sig
  include Data.Repo.Sig.REPO

  val insert_file :
    Core.Ctx.t -> file:StoredFile.t -> (unit, string) Result.t Lwt.t

  val insert_blob :
    Core.Ctx.t -> id:string -> blob:string -> (unit, string) Result.t Lwt.t

  val get_file :
    Core.Ctx.t -> id:string -> (StoredFile.t option, string) Result.t Lwt.t

  val get_blob :
    Core.Ctx.t -> id:string -> (string option, string) Result.t Lwt.t

  val update_file :
    Core.Ctx.t -> file:StoredFile.t -> (unit, string) Result.t Lwt.t

  val update_blob :
    Core.Ctx.t -> id:string -> blob:string -> (unit, string) Result.t Lwt.t
end

module type SERVICE = sig
  include Core_container.SERVICE

  val get_file :
    Core.Ctx.t -> id:string -> (StoredFile.t option, string) Lwt_result.t
  (** Get the meta data of a complete file.

      This will not download the content, use [get_data_base64] for that.
*)

  val upload_base64 :
    Core.Ctx.t ->
    file:File.t ->
    base64:string ->
    (StoredFile.t, string) Lwt_result.t
  (** Upload base64 string as data content for [file]. *)

  val update_base64 :
    Core.Ctx.t ->
    file:StoredFile.t ->
    base64:string ->
    (StoredFile.t, string) Lwt_result.t
  (** Upload and overwrite base64 strong content of [file]. *)

  val get_data_base64 :
    Core.Ctx.t -> file:StoredFile.t -> (string option, string) Lwt_result.t
  (** Download actual file content for [file]. *)
end
