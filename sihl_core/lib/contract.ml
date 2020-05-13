module Email = Contract_email
module Migration = Contract_migration

module type REPOSITORY = sig
  val migrate : unit -> Migration.migration

  val clean : Db.connection -> unit Db.db_result
end
