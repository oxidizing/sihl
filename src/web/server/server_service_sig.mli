module type SERVICE = sig
  include Core.Container.Service.Sig

  (** Register HTTP routes that are served by the web server. *)
  val register_endpoints : Server_core.endpoint list -> unit

  (** Start a HTTP server.

      This Lwt.t resolves immediately and the web server starts in the background. The web
      server serves the registered routes. *)
  val start_server : Core.Ctx.t -> unit Lwt.t

  val configure
    :  Server_core.endpoint list
    -> Core.Configuration.data
    -> Core.Container.Service.t
end
