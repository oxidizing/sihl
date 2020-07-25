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

  val upload_base64 :
    Core.Ctx.t ->
    file:File.t ->
    base64:string ->
    (StoredFile.t, string) Lwt_result.t

  val update_base64 :
    Core.Ctx.t ->
    file:StoredFile.t ->
    base64:string ->
    (StoredFile.t, string) Lwt_result.t

  val get_data_base64 :
    Core.Ctx.t -> file:StoredFile.t -> (string option, string) Lwt_result.t
end
