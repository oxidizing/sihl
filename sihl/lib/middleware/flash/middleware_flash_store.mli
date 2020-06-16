val find_current :
  Opium_kernel.Request.t ->
  (Middleware_flash_model.Message.t option, Core_error.t) Result.t Lwt.t

val set_next :
  Opium_kernel.Request.t ->
  Middleware_flash_model.Message.t ->
  (unit, Core_error.t) Result.t Lwt.t

val rotate : Opium_kernel.Request.t -> (unit, Core_error.t) Result.t Lwt.t
