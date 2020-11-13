(** A module to manage the service container and service lifecycles.

    The service container knows how to start services in the right order by respecting the
    defined dependencies. Use it to implement your own services. *)

(** {1 Lifecycle}

    Every service has a lifecycle, meaning it can be started and stopped. **)

module Lifecycle : sig
  type t
  type start = unit -> unit Lwt.t
  type stop = unit -> unit Lwt.t

  val name : t -> string
  val create : ?dependencies:t list -> string -> start:start -> stop:stop -> t
end

(** {1 Service}

    A service has a [start] and [stop] functions and a lifecycle. **)

module Service : sig
  module type Sig = sig
    val lifecycle : Lifecycle.t
  end

  type t

  val commands : t -> Command.t list
  val configuration : t -> Configuration.t

  val create
    :  ?commands:Command.t list
    -> ?configuration:Configuration.t
    -> Lifecycle.t
    -> t
end

(** [start_services lifecycles] starts a list of service [lifecycles]. The order does not
    matter as the services are started in the order of their dependencies. (No service is
    started before its dependency) *)
val start_services : Service.t list -> Lifecycle.t list Lwt.t

(** [stop_services ctx services] stops a list of service [lifecycles] with a context
    [ctx]. The order does not matter as the services are stopped in the order of their
    dependencies. (No service is stopped after its dependency) *)
val stop_services : Service.t list -> unit Lwt.t

module Map : sig
  type 'a t
end

val collect_all_lifecycles : Lifecycle.t list -> Lifecycle.t Map.t
val top_sort_lifecycles : Lifecycle.t list -> Lifecycle.t list
