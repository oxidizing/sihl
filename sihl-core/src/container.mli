(** A module to manage the service container and service lifecycles.

    The service container knows how to start services in the right order by
    respecting the defined dependencies. Use it to implement your own services. *)

(** {1 Lifecycle}

    Every service has a lifecycle, meaning it can be started and stopped. **)

type lifecycle

val create_lifecycle
  :  ?dependencies:(unit -> lifecycle list)
  -> ?start:(unit -> unit Lwt.t)
  -> ?stop:(unit -> unit Lwt.t)
  -> ?implementation:string
  -> string
  -> lifecycle

(** [build_name lifecycle] returns the globally unique name of the [lifecycle]
    by concatenating its name and its implementation. *)
val build_name : lifecycle -> string

(** [build_name lifecycle] returns the globally unique name of the [lifecycle]
    by concatenating its name and its implementation. *)
val set_implementation : ?implementation:string -> lifecycle -> lifecycle

(** {1 Service}

    A service has a [start] and [stop] functions and a lifecycle. **)

module Service : sig
  module type Sig = sig
    val lifecycle : lifecycle
  end

  type t

  val commands : t -> Command.t list
  val configuration : t -> Configuration.t

  val create
    :  ?commands:Command.t list
    -> ?configuration:Configuration.t
    -> ?server:bool
    -> lifecycle
    -> t

  val server : t -> bool
  val start : t -> unit Lwt.t
  val name : t -> string
end

(** [start_services lifecycles] starts a list of service [lifecycles]. The order
    does not matter as the services are started in the order of their
    dependencies. (No service is started before its dependency) *)
val start_services : Service.t list -> lifecycle list Lwt.t

(** [stop_services ctx services] stops a list of service [lifecycles] with a
    context [ctx]. The order does not matter as the services are stopped in the
    order of their dependencies. (No service is stopped after its dependency) *)
val stop_services : Service.t list -> unit Lwt.t

module Map : sig
  type 'a t
end

val collect_all_lifecycles : lifecycle list -> lifecycle Map.t
val top_sort_lifecycles : lifecycle list -> lifecycle list
val unpack : string -> ?default:'a -> 'a option ref -> 'a
