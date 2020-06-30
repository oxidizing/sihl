(* RepoService *)

type cleaner = Core_db.connection -> (unit, string) Result.t Lwt.t

module Meta : sig
  type t

  val equal : t -> t -> bool

  val show : t -> string

  val pp : Format.formatter -> t -> unit

  val total : t -> int

  val make : total:int -> t
end

val register_cleaner : Core.Ctx.t -> cleaner -> (unit, string) Result.t Lwt.t

val register_cleaners :
  Core.Ctx.t -> cleaner list -> (unit, string) Result.t Lwt.t

val clean_all : Core.Ctx.t -> (unit, string) Result.t Lwt.t
