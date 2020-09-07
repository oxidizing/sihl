(** This module implements regex and exposes a high-level API for the most common use cases.

*)

type t = Pcre.regexp

val of_string : string -> t

val test : t -> string -> bool

val extract_last : t -> string -> string option

module Pcre = Pcre
