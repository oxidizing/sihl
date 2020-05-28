module Message = Middleware_flash_model.Message

val key : string Opium.Hmap.key

val m : unit -> Opium_kernel.Rock.Middleware.t

val current : Opium_kernel.Request.t -> Message.t option Lwt.t

val set : Opium_kernel.Request.t -> Message.t -> unit Lwt.t

val set_success : Opium_kernel.Request.t -> string -> unit Lwt.t

val set_error : Opium_kernel.Request.t -> string -> unit Lwt.t

val redirect_with_error :
  Opium_kernel.Request.t -> path:string -> string -> Http.Res.t Lwt.t

val redirect_with_success :
  Opium_kernel.Request.t -> path:string -> string -> Http.Res.t Lwt.t
