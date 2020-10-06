(** Use this module to create user sessions and to read and write session data. *)

(** The session service exposes a key-value store that is scoped by user session *)
module Service = Service

module Sig = Sig

type data_map = Model.data_map
type data = Model.data
type t = Model.t

module Map : sig
  type 'a t
end

val key : t -> string
val data : t -> string Map.t
val is_expired : Ptime.t -> t -> bool
val data_of_string : string -> (data, string) Result.t
val string_of_data : data -> string
val get : string -> t -> string option
val set : key:string -> value:string -> t -> t
val remove : key:string -> t -> t
val pp : Format.formatter -> t -> unit
val t : t Caqti_type.t
