module type SERVICE = sig
  val on_bind : Core_ctx.t -> (unit, string) Lwt_result.t

  val on_start : Core_ctx.t -> (unit, string) Lwt_result.t

  val on_stop : Core_ctx.t -> (unit, string) Lwt_result.t
end
