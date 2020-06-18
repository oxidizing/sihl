module Key : sig
  type 'a t

  val create : string -> 'a t

  val info : 'a t -> string
end

type 'a key = 'a Key.t

module Binding : sig
  type t

  val get_repo : t -> Sig.repo option

  val create : 'a key -> 'a -> t

  val apply : t -> unit

  val register : 'a key -> 'a -> unit

  val register_service :
    (module Sig.SERVICE) key -> (module Sig.SERVICE) -> unit
end

val get_opt : 'a key -> 'a option

val get : 'a key -> 'a

type binding = Binding.t

val register : 'a key -> 'a -> unit

val register_service : (module Sig.SERVICE) key -> (module Sig.SERVICE) -> unit

val bind : 'a key -> 'a -> binding

val create_binding : 'a key -> 'a -> Sig.repo option -> binding

val set_initialized : unit -> unit
