module File : sig
  type t
end

module UploadedFile : sig
  type t
end

module type SERVICE = sig
  val upload_base64 :
    Http.Req.t ->
    file:File.t ->
    base64:string ->
    (UploadedFile.t, string) Lwt_result.t

  val update_base64 :
    Http.Req.t ->
    file:UploadedFile.t ->
    base64:string ->
    (UploadedFile.t, string) Lwt_result.t

  val get_data_base64 :
    Http.Req.t -> file:UploadedFile.t -> (string option, string) Lwt_result.t

  val provide_repo : Sig.repo option
end

module type REPO = sig
  include Sig.REPO

  val insert_file :
    Core.Db.connection -> file:UploadedFile.t -> unit Core.Db.db_result

  val insert_blob :
    Core.Db.connection -> id:string -> blob:string -> unit Core.Db.db_result

  val get_blob :
    Core.Db.connection -> id:string -> string option Core.Db.db_result

  val update_file :
    Core.Db.connection -> file:UploadedFile.t -> unit Core.Db.db_result

  val update_blob :
    Core.Db.connection -> id:string -> blob:string -> unit Core.Db.db_result
end

module Make : functor (Repo : REPO) -> SERVICE

val mariadb : Core.Registry.Binding.t
