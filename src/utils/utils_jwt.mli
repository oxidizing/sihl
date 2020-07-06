type algorithm = Jwto.algorithm = HS256 | HS512 | Unknown

type t = Jwto.t

type payload

val empty : payload

val add_claim : key:string -> value:string -> payload -> payload

val encode : algorithm -> secret:string -> payload -> (string, string) result

val decode : secret:string -> string -> (t, string) result

val get_claim : key:string -> t -> string option

val pp : Format.formatter -> t -> unit

val eq : t -> t -> bool

module Jwto = Jwto
