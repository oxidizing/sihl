module type REPO = sig
  val migrate : unit -> Migration_model.Migration.t

  val clean : Core_db.connection -> (unit, string) Result.t Lwt.t
end
