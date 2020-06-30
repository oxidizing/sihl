module type SERVICE = sig
  val on_bind : Core_ctx.t -> (unit, string) Lwt_result.t

  val on_start : Core_ctx.t -> (unit, string) Lwt_result.t

  val on_stop : Core_ctx.t -> (unit, string) Lwt_result.t
end

module type REPO = sig
  val migrate : unit -> Migration_model.Migration.t

  val clean : Core_db.connection -> (unit, string) Result.t Lwt.t
end
