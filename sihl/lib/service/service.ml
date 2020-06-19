module type SERVICE = sig
  val on_bind : Opium_kernel.Request.t -> (unit, string) Lwt_result.t

  val on_start : Opium_kernel.Request.t -> (unit, string) Lwt_result.t

  val on_stop : Opium_kernel.Request.t -> (unit, string) Lwt_result.t
end
