val find_current :
  Opium_kernel.Request.t -> Middleware_flash_model.Message.t option Lwt.t

val set_next :
  Opium_kernel.Request.t -> Middleware_flash_model.Message.t -> unit Lwt.t

val rotate : Opium_kernel.Request.t -> unit Lwt.t
