open Base

module Message : sig
  type t = Error of string | Warning of string | Success of string

  val pp : Caml.Format.formatter -> t -> unit

  val equal : t -> t -> bool
end

module Entry : sig
  type t = { current : Message.t option; next : Message.t option }

  val create : Message.t -> t

  val current : t -> Message.t option

  val next : t -> Message.t option

  val rotate : t -> t
end
