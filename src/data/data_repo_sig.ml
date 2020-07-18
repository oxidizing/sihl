module type REPO = sig
  val migrate : unit -> Data_migration_core.Migration.t

  val clean : Data_db_core.connection -> (unit, string) Result.t Lwt.t
end

module type SERVICE = sig
  val register_cleaner : 'a -> Data_repo_core.cleaner -> (unit, 'b) result Lwt.t

  val register_cleaners :
    'a -> Data_repo_core.cleaner list -> (unit, 'b) result Lwt.t

  val clean_all : Core_ctx.t -> (unit, string) Lwt_result.t
end
