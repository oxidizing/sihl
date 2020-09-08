module type SERVICE = sig
  include Core.Container.SERVICE

  val register_seed : Seed_core.t -> unit
  (** [register_seed seed] adds [seed] to the already registered seeds. Raises if a seed with the same name already exists. *)

  val register_seeds : Seed_core.t list -> unit
  (** [register_seeds seeds] adds [seeds] to the already registered seeds. Raises if a seed with the same name already exists. *)

  val get_seeds : unit -> Seed_core.t list
  (** [get_seeds ()] returns the list of registered seeds. *)

  val run_seed : Core.Ctx.t -> string -> unit Lwt.t
  (** [run_seed ctx name] executed the seed with [name] by using the [ctx] as request context.*)
end
