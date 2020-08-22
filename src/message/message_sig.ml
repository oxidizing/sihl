module type Service = sig
  val fetch_entry : Core_ctx.t -> Message_core.Entry.t option Lwt.t

  val find_current : Core_ctx.t -> Message_core.Message.t option Lwt.t

  val set_next : Core_ctx.t -> Message_core.Message.t -> unit Lwt.t

  val rotate : Core_ctx.t -> Message_core.Message.t option Lwt.t

  val current : Core_ctx.t -> Message_core.Message.t option Lwt.t

  val set :
    Core_ctx.t ->
    ?error:string list ->
    ?warning:string list ->
    ?success:string list ->
    ?info:string list ->
    unit ->
    unit Lwt.t
  (** Set flash message for the current session.

      Flash messages can be used to transport information across request response lifecycles. The typical use case is giving a user feedback after a form submission.

      Requires middlewares: Session & Message
*)
end
