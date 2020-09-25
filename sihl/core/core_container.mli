(** The service container manages service lifecycles. It knows how to start services in the right order by respecting the defined dependencies. Use it to implement you own services.
 *)

type start = Core_ctx.t -> Core_ctx.t Lwt.t

type stop = Core_ctx.t -> unit Lwt.t

module Lifecycle : sig
  type t

  val stop : t -> Core_ctx.t -> unit Lwt.t

  val start : t -> Core_ctx.t -> Core_ctx.t Lwt.t

  val dependencies : t -> t list

  val module_name : t -> string

  val make : start:start -> stop:stop -> ?dependencies:t list -> string -> t
end

module type SERVICE = sig
  val lifecycle : Lifecycle.t

  val start : start

  val stop : stop
end

val collect_all_lifecycles :
  (module SERVICE) list ->
  (string, Lifecycle.t, Base.String.comparator_witness) Base.Map.t

val top_sort_lifecycles : (module SERVICE) list -> Lifecycle.t list

val start_services :
  (module SERVICE) list -> ((module SERVICE) list * Core_ctx.t) Lwt.t

val stop_services : Core_ctx.t -> (module SERVICE) list -> unit Lwt.t
