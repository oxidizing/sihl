module Core = Sihl_core
include Core.Container.Service.Sig

(** Start a HTTP server.

    This Lwt.t resolves immediately and the web server starts in the background. The web
    server serves the registered routes. *)
val start_server : unit -> unit Lwt.t

(** [register routers] creates an HTTP server with [endpoints] and [configuration]. *)
val register : ?routers:Route.router list -> unit -> Core.Container.Service.t
