module type SERVICE = sig
  include Core.Container.SERVICE

  val register_endpoints : Server_core.endpoint list -> unit
  (** Register HTTP routes that are served by the web server. *)

  val start_server : Core.Ctx.t -> unit Lwt.t
  (** Start a HTTP server.

      This Lwt.t resolves immediately and the web server starts in the background. The web server serves the registered routes.
*)
end
