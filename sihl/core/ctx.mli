(** The service request context is a dynamic store that can be used to add, find and
    remove values. *)

type t
type 'a key

val empty : t
val add : 'a key -> 'a -> t -> t
val find : 'a key -> t -> 'a option
val remove : 'a key -> t -> t
val create_key : unit -> 'a key
val id : t -> string
