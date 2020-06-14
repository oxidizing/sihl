open Core.Contract.Migration.State

val create : namespace:string -> t

val mark_dirty : t -> t

val mark_clean : t -> t

val increment : t -> t

val steps_to_apply : 'a * 'b list -> t -> 'a * 'b list

val of_tuple : string * int * bool -> t

val to_tuple : t -> string * int * bool

val dirty : t -> bool
