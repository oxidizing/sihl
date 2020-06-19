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

  val set_mime : string -> t -> t

  val set_filesize : int -> t -> t

  val set_filename : string -> t -> t
end

module StoredFile : sig
  type t

  val mime : t -> string

  val filesize : t -> int

  val filename : t -> string

  val blob : t -> string

  val file : t -> File.t

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  val pp : Format.formatter -> t -> unit

  val show : t -> string

  val equal : t -> t -> bool

  val make : file:File.t -> blob:string -> t

  val set_mime : string -> t -> t

  val set_filesize : int -> t -> t

  val set_filename : string -> t -> t
end

module type SERVICE = sig
  include Sig.SERVICE

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

module Make : functor (Repo : REPO) -> SERVICE

val mariadb : Core.Container.Binding.t

val upload_base64 :
  Http.Req.t ->
  file:File.t ->
  base64:string ->
  (StoredFile.t, string) Lwt_result.t

val get_file :
  Http.Req.t -> id:string -> (StoredFile.t option, string) Lwt_result.t

val update_base64 :
  Http.Req.t ->
  file:StoredFile.t ->
  base64:string ->
  (StoredFile.t, string) Lwt_result.t

val get_data_base64 :
  Http.Req.t -> file:StoredFile.t -> (string option, string) Lwt_result.t
