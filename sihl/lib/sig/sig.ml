type repo = (Core_db.connection -> unit Core_db.db_result) * Migration_sig.t
[@@deriving show]

let migration (_, migration) = migration

let cleaner (cleaner, _) = cleaner

module type REPO = sig
  val migrate : unit -> Migration_sig.t

  val clean : Core_db.connection -> unit Core_db.db_result
end

module type SERVICE = sig
  val provide_repo : repo option
end
