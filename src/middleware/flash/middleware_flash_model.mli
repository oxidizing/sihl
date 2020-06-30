open Base

module Message : sig
  type t = Error of string | Warning of string | Success of string

  val pp : Caml.Format.formatter -> t -> unit

  val equal : t -> t -> bool

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> (t, string) Result.t

  val success : string -> t

  val warning : string -> t

  val error : string -> t
end

module Entry : sig
  type t = { current : Message.t option; next : Message.t option }

  val pp : Caml.Format.formatter -> t -> unit

  val equal : t -> t -> bool

  val empty : t

  val create : Message.t -> t

  val current : t -> Message.t option

  val next : t -> Message.t option

  val set_next : Message.t -> t -> t

  val set_current : Message.t -> t -> t

  val rotate : t -> t

  val to_string : t -> string

  val of_string : string -> (t, string) Result.t
end
