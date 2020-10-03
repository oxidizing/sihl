type t

type meth =
  | Get
  | Post
  | Put
  | Delete
  | All

val pp : Format.formatter -> t -> unit
val show : t -> string
val equal : t -> t -> bool

type handler = Core.Ctx.t -> Res.t Lwt.t

val handler : t -> handler
val meth : t -> meth
val path : t -> string
val set_handler : handler -> t -> t
val get : string -> handler -> t
val post : string -> handler -> t
val put : string -> handler -> t
val delete : string -> handler -> t
val all : string -> handler -> t
val prefix : string -> t -> t
