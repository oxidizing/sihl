module type REPO = sig
  val register_migration : Core.Ctx.t -> unit Lwt.t

  val register_cleaner : Core.Ctx.t -> unit Lwt.t
end

module type SERVICE = sig
  include Core.Container.SERVICE

  val register_cleaner : 'a -> Data_repo_core.cleaner -> unit Lwt.t
  (** Register repository cleaner function.

      A cleaner function is used during integration testing to efficiently clean repositories. *)

  val register_cleaners : 'a -> Data_repo_core.cleaner list -> unit Lwt.t
  (** Register repository cleaner functions. *)

  val clean_all : Core_ctx.t -> unit Lwt.t
  (** Run all registered repository cleaners.

      Use this carefully, running [clean_all] leads to data loss! *)
end
