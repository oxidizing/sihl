module type SERVICE = sig
  val fetch_entry : Core.Ctx.t -> Message_core.Entry.t option Lwt.t

  val find_current : Core.Ctx.t -> Message_core.Message.t option Lwt.t

  val set_next : Core.Ctx.t -> Message_core.Message.t -> unit Lwt.t

  val rotate : Core.Ctx.t -> Message_core.Message.t option Lwt.t

  val current : Core.Ctx.t -> Message_core.Message.t option Lwt.t

  val set :
    Core.Ctx.t ->
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
