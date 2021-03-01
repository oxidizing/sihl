type meth =
  | Get
  | Post
  | Put
  | Delete
  | Any

type handler = Rock.Request.t -> Rock.Response.t Lwt.t
type t = meth * string * handler

type router =
  { scope : string
  ; routes : t list
  ; middlewares : Rock.Middleware.t list
  }

let name = "http"

module type Sig = sig
  val register : ?routers:router list -> unit -> Core_container.Service.t

  include Core_container.Service.Sig
end
