module Meta : sig
  type t

  val equal : t -> t -> bool

  val show : t -> string

  val pp : Format.formatter -> t -> unit

  val total : t -> int

  val make : total:int -> t
end

val hex_to_uuid : string -> string

val set_fk_check : Core.Db.connection -> bool -> unit Core.Db.db_result
