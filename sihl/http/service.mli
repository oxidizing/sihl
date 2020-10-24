include Core.Container.Service.Sig

type meth =
  | Get
  | Post
  | Put
  | Delete
  | Any

type route = meth * string * (Opium_kernel.Request.t -> Opium_kernel.Response.t Lwt.t)

type router =
  { scope : string
  ; routes : route list
  ; middlewares : Opium_kernel.Rock.Middleware.t list
  }

(** Start a HTTP server.

    This Lwt.t resolves immediately and the web server starts in the background. The web
    server serves the registered routes. *)
val start_server : Core.Ctx.t -> unit Lwt.t

(** [configure endpoints configuration service] creates an HTTP server with [endpoints]
    and [configuration]. *)
val configure : router list -> Core.Configuration.data -> Core.Container.Service.t
