module type REPO = sig
  val register_migration : unit -> unit
  val register_cleaner : unit -> unit
end

module type SERVICE = sig
  include Core.Container.Service.Sig

  (** Register repository cleaner function.

      A cleaner function is used during integration testing to efficiently clean
      repositories. *)
  val register_cleaner : Model.cleaner -> unit

  (** Register repository cleaner functions. *)
  val register_cleaners : Model.cleaner list -> unit

  (** Run all registered repository cleaners.

      Use this carefully, running [clean_all] leads to data loss! *)
  val clean_all : Core.Ctx.t -> unit Lwt.t

  val configure : Core.Configuration.data -> Core.Container.Service.t
end
