type meth =
  | Get
  | Post
  | Put
  | Delete
  | Any

type handler = Rock.Request.t -> Rock.Response.t Lwt.t
type t = meth * string * handler

val get : string -> handler -> t
val post : string -> handler -> t
val put : string -> handler -> t
val delete : string -> handler -> t
val any : string -> handler -> t

type router =
  { scope : string
  ; routes : t list
  ; middlewares : Rock.Middleware.t list
  }

val router : ?scope:string -> ?middlewares:Rock.Middleware.t list -> t list -> router
val prefix : string -> t -> t
val router_to_routes : router -> t list
val externalize_path : ?prefix:string -> string -> string
