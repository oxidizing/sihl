(** Use this module to create user sessions and to read and write session data. *)

module Service = Session_service
(** The session service exposes a key-value store that is scoped by user session *)

module Schedule = Session_schedule

type data_map = Session_core.data_map

type data = Session_core.data

type t = Session_core.t

val key : t -> string

val data : t -> (string, string, Base.String.comparator_witness) Base.Map.t

val is_expired : Ptime.t -> t -> bool

val data_of_string : string -> (data, string) Result.t

val string_of_data : data -> string

val get : string -> t -> string option

val set : key:string -> value:string -> t -> t

val remove : key:string -> t -> t

val pp : Format.formatter -> t -> unit

val t : t Caqti_type.t
