module type REPO = sig
  val migrate : unit -> Data_migration_core.Migration.t

  val clean : Data_db_core.connection -> (unit, string) Result.t Lwt.t
end
