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
val before_start : (unit -> unit Lwt.t) -> t -> t

(** [after_stop f app] registers a callback f with [app]. The callback is executed before
    after services are stopped. This means you must not use any services here! *)
val after_stop : (unit -> unit Lwt.t) -> t -> t

(** [run ?commands ?log_reporter app] is the main entry point to a Sihl app and starts the
    command line interface with [commands] merged with the commands provided by services.

    An optional [log_reporter] can be provided to change the logging behavior. The default
    log reporter logs to stdout. *)
val run
  :  ?commands:Command.t list
  -> ?log_reporter:(unit -> Logs.reporter)
  -> ?args:string list
  -> t
  -> unit

(** [run' ?commands ?log_reporter app] is analogous to [run]. It is a helper to be used in
    tests that need [Lwt.t]. *)
val run'
  :  ?commands:Command.t list
  -> ?log_reporter:(unit -> Logs.reporter)
  -> ?args:string list
  -> t
  -> unit Lwt.t
