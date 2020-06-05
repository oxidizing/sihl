type t = Pcre.regexp

val of_string : string -> t

val test : t -> string -> bool

val extract_last : t -> string -> string option

module Internal_ = Pcre
