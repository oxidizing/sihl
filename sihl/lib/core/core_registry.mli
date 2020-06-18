module Key : sig
  type 'a t

  val create : string -> 'a t

  val info : 'a t -> string
end

type 'a key = 'a Key.t

module Binding : sig
  type t

  val create : 'a key -> 'a -> t

  val apply : t -> unit

  val register : 'a key -> 'a -> unit
end

val get_opt : 'a key -> 'a option

val get : 'a key -> 'a

type binding = Binding.t

val register : 'a key -> 'a -> unit

val bind : 'a key -> 'a -> binding

val set_initialized : unit -> unit
