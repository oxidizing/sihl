(* RepoService *)

type cleaner = Core_db.connection -> unit Core_db.db_result

module Meta : sig
  type t

  val equal : t -> t -> bool

  val show : t -> string

  val pp : Format.formatter -> t -> unit

  val total : t -> int

  val make : total:int -> t
end

val set_fk_check : Core.Db.connection -> bool -> unit Core.Db.db_result

val register_cleaner :
  Opium_kernel.Request.t -> cleaner -> (unit, string) Result.t Lwt.t

val register_cleaners :
  Opium_kernel.Request.t -> cleaner list -> (unit, string) Result.t Lwt.t

val clean_all : Opium_kernel.Request.t -> (unit, string) Result.t Lwt.t
