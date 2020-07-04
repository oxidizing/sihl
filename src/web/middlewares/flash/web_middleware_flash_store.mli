val find_current :
  Core.Ctx.t ->
  (Web_middleware_flash_model.Message.t option, string) Result.t Lwt.t

val set_next :
  Core.Ctx.t ->
  Web_middleware_flash_model.Message.t ->
  (unit, string) Result.t Lwt.t

val rotate : Core.Ctx.t -> (unit, string) Result.t Lwt.t
