(** Hashing strings and comparing hashes. *)

val hash : ?count:int -> string -> (string, string) Result.t

val matches : hash:string -> plain:string -> bool

module Bcrypt = Bcrypt
