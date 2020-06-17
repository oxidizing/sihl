type t

val random : unit -> t

val of_string : string -> (t, string) Result.t

val to_string : t -> string

val is_valid_str : string -> bool

val pp : Format.formatter -> t -> unit

val equal : t -> t -> bool

module Uuidm = Uuidm
