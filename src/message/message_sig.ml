module type Service = sig
  val fetch_entry :
    Core_ctx.t -> (Message_core.Entry.t option, string) Lwt_result.t

  val find_current :
    Core_ctx.t -> (Message_core.Message.t option, string) Lwt_result.t

  val set_next :
    Core_ctx.t -> Message_core.Message.t -> (unit, string) Lwt_result.t

  val rotate :
    Core_ctx.t -> (Message_core.Message.t option, string) Lwt_result.t

  val current :
    Core_ctx.t -> (Message_core.Message.t option, string) Lwt_result.t

  val set :
    Core_ctx.t ->
    ?error:string list ->
    ?warning:string list ->
    ?success:string list ->
    ?info:string list ->
    unit ->
    (unit, string) Lwt_result.t
end
