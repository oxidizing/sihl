module Meta : sig
  type t

  val equal : t -> t -> bool

  val show : t -> string

  val pp : Format.formatter -> t -> unit

  val total : t -> int

  val make : total:int -> t
end

module Migration = Repo_migration
