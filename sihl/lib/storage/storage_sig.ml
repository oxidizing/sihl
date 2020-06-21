open Storage_model

module type SERVICE = sig
  include Service.SERVICE

  val get_file :
    Http.Req.t -> id:string -> (StoredFile.t option, string) Lwt_result.t

  val upload_base64 :
    Http.Req.t ->
    file:File.t ->
    base64:string ->
    (StoredFile.t, string) Lwt_result.t

  val update_base64 :
    Http.Req.t ->
    file:StoredFile.t ->
    base64:string ->
    (StoredFile.t, string) Lwt_result.t

  val get_data_base64 :
    Http.Req.t -> file:StoredFile.t -> (string option, string) Lwt_result.t
end

module type REPO = sig
  include Sig.REPO

  val insert_file :
    Core.Db.connection -> file:StoredFile.t -> unit Core.Db.db_result

  val insert_blob :
    Core.Db.connection -> id:string -> blob:string -> unit Core.Db.db_result

  val get_file :
    Core.Db.connection -> id:string -> StoredFile.t option Core.Db.db_result

  val get_blob :
    Core.Db.connection -> id:string -> string option Core.Db.db_result

  val update_file :
    Core.Db.connection -> file:StoredFile.t -> unit Core.Db.db_result

  val update_blob :
    Core.Db.connection -> id:string -> blob:string -> unit Core.Db.db_result
end
