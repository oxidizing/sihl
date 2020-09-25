type t

type 'a key

val empty : t

val add : 'a key -> 'a -> t -> t

val find : 'a key -> t -> 'a option

val remove : 'a key -> t -> t

val create_key : unit -> 'a key

val id : t -> string
