include Core.Container.Service.Sig

(** Start a HTTP server.

    This Lwt.t resolves immediately and the web server starts in the background. The web
    server serves the registered routes. *)
val start_server : Core.Ctx.t -> unit Lwt.t

(** [configure endpoints configuration service] creates an HTTP server with [endpoints]
    and [configuration]. *)
val configure : Route.router list -> Core.Configuration.data -> Core.Container.Service.t
