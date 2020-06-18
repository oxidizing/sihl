module File : sig
  type t

  val mime : t -> string

  val filesize : t -> int

  val filename : t -> string

  val id : t -> string

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  val pp : Format.formatter -> t -> unit

  val show : t -> string

  val equal : t -> t -> bool

  val make : id:string -> filename:string -> filesize:int -> mime:string -> t
end

module UploadedFile : sig
  type t

  val blob : t -> string

  val file : t -> File.t

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  val pp : Format.formatter -> t -> unit

  val show : t -> string

  val equal : t -> t -> bool

  val make : file:File.t -> blob:string -> t
end

module type SERVICE = sig
  include Sig.SERVICE

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
