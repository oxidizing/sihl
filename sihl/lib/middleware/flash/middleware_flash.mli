module Message = Middleware_flash_model.Message
module Entry = Middleware_flash_model.Entry

val key : string Opium.Hmap.key

val m : unit -> Opium_kernel.Rock.Middleware.t

val current : Core.Ctx.t -> (Message.t option, string) Result.t Lwt.t

val set : Core.Ctx.t -> Message.t -> (unit, string) Result.t Lwt.t

val set_success : Core.Ctx.t -> string -> (unit, string) Result.t Lwt.t

val set_error : Core.Ctx.t -> string -> (unit, string) Result.t Lwt.t

val redirect_with_error :
  Core.Ctx.t -> path:string -> string -> (Http.Res.t, string) Result.t Lwt.t

val redirect_with_success :
  Core.Ctx.t -> path:string -> string -> (Http.Res.t, string) Result.t Lwt.t
