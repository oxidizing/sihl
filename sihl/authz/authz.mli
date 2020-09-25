(** Authorization deals with the question whether a user is allowed to do something. Use this module to separate the definition of who is allowed to do what from checking it.
*)

type guard = bool * string

val authorize : guard -> (unit, string) Result.t

val any : guard list -> string -> (unit, string) Result.t
