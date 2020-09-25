type t = Yojson.Safe.t
(** Parsing, decoding and encoding JSON. *)

val parse : string -> (t, string) result

val parse_opt : string -> t option

val parse_exn : string -> t

val to_string : ?buf:Bi_outbuf.t -> ?len:int -> ?std:bool -> t -> string

module Yojson = Yojson.Safe
