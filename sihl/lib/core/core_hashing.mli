val hash : ?count:int -> string -> (string, string) Result.t

val does_match : hash:string -> plain:string -> bool

module Bcrypt = Bcrypt
