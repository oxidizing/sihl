type guard = bool * string

val authorize : guard -> (unit, string) Result.t

val any : guard list -> string -> (unit, string) Result.t
