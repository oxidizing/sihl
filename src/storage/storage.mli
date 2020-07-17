module Sig = Storage_sig

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
