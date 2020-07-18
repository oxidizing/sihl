module type SERVICE = sig
  val on_init : Core_ctx.t -> (unit, string) Lwt_result.t

  val on_start : Core_ctx.t -> (unit, string) Lwt_result.t

  val on_stop : Core_ctx.t -> (unit, string) Lwt_result.t
end

val register_services :
  Core_ctx.t -> (module SERVICE) list -> (unit, string) Lwt_result.t

val start_services : Core_ctx.t -> (unit, string) Lwt_result.t

val stop_services : Core_ctx.t -> (unit, string) Lwt_result.t
