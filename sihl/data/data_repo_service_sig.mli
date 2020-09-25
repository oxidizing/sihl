module type REPO = sig
  val register_migration : unit -> unit

  val register_cleaner : unit -> unit
end

module type SERVICE = sig
  include Core.Container.SERVICE

  val register_cleaner : Data_repo_core.cleaner -> unit
  (** Register repository cleaner function.

      A cleaner function is used during integration testing to efficiently clean repositories. *)

  val register_cleaners : Data_repo_core.cleaner list -> unit
  (** Register repository cleaner functions. *)

  val clean_all : Core.Ctx.t -> unit Lwt.t
  (** Run all registered repository cleaners.

      Use this carefully, running [clean_all] leads to data loss! *)
end
