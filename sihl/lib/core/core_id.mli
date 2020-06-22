type t = Uuidm.t

val random : unit -> t

val of_string : string -> (t, string) Result.t

val of_bytes : string -> (t, string) Result.t

val to_string : t -> string

val to_bytes : t -> string

val is_valid_str : string -> bool

val pp : Format.formatter -> t -> unit

val equal : t -> t -> bool

val t_string : string Caqti_type.t

val t : t Caqti_type.t

module Uuidm = Uuidm
