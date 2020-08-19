module type REPO = sig
  val register_migration : Core.Ctx.t -> (unit, string) Result.t Lwt.t

  val register_cleaner : Core.Ctx.t -> (unit, string) Result.t Lwt.t
end

module type SERVICE = sig
  include Core.Container.SERVICE

  val register_cleaner : 'a -> Data_repo_core.cleaner -> (unit, 'b) result Lwt.t
  (** Register repository cleaner function.

        A cleaner function is used during integration testing to efficiently clean repositories. *)

  val register_cleaners :
    'a -> Data_repo_core.cleaner list -> (unit, 'b) result Lwt.t
  (** Register repository cleaner functions. *)

  val clean_all : Core_ctx.t -> (unit, string) Lwt_result.t
  (** Run all registered repository cleaners.

        Use this carefully, running [clean_all] leads to data loss! *)
end
