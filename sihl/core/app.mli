(** A module to create Sihl apps. *)

(** An app is a thin convenience layer on top of the service container. It provides hooks
    that are executed at different stages in the app lifecycle. *)
type t

(** [empty] returns an app without any services. *)
val empty : t

(** [with_services services app] adds [services] to an [app]. *)
val with_services : Container.Service.t list -> t -> t

(** [before_start f app] registers a callback f with [app]. The callback is executed
    before any service is started. This means you must not use any services here! *)
val before_start : (Ctx.t -> unit Lwt.t) -> t -> t

(** [after_start f app] registers a callback f with [app]. The callback is executed after
    all services are started. You can safely use services here. *)
val after_start : (Ctx.t -> unit Lwt.t) -> t -> t

(** [before_stop f app] registers a callback f with [app]. The callback is executed before
    all services are stopped. You can safely use services here. *)
val before_stop : (Ctx.t -> unit Lwt.t) -> t -> t

(** [after_stop f app] registers a callback f with [app]. The callback is executed before
    after services are stopped. This means you must not use any services here! *)
val after_stop : (Ctx.t -> unit Lwt.t) -> t -> t

(** [run ?commands ?configuration ?log_reporter app] is the main entry point to a Sihl app
    and starts the command line interface with [commands] merged with the commands
    provided by services.

    [configuration] can be provided globally, overriding the configurations provided to
    the services.

    An optional [log_reporter] can be provided to change the logging behavior. The default
    log reporter logs to stdout. *)
val run
  :  ?commands:Command.t list
  -> ?configuration:Configuration.data
  -> ?log_reporter:(unit -> Logs.reporter)
  -> ?args:string list
  -> t
  -> unit
