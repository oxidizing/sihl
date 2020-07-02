type t

(* TODO get rid of Core_fail.error and just return string*)
type handler = Web_req.t -> (Web_res.t, Core_fail.error) result Lwt.t

val pp : Format.formatter -> t -> unit

val show : t -> string

val equal : t -> t -> bool

val get : string -> handler -> t

val post : string -> handler -> t

val put : string -> handler -> t

val delete : string -> handler -> t

val all : string -> handler -> t
