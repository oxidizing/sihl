module Core = Sihl_core
module Session = Sihl_session

module type SERVICE = sig
  val fetch_entry : Session.t -> Model.Entry.t option Lwt.t
  val find_current : Session.t -> Model.Message.t option Lwt.t
  val set_next : Session.t -> Model.Message.t -> unit Lwt.t
  val rotate : Session.t -> Model.Message.t option Lwt.t
  val current : Session.t -> Model.Message.t option Lwt.t

  (** Set flash message for the current session.

      Flash messages can be used to transport information across request response
      lifecycles. The typical use case is giving a user feedback after a form submission.

      Requires middlewares: Session & Message *)
  val set
    :  Session.t
    -> ?error:string list
    -> ?warning:string list
    -> ?success:string list
    -> ?info:string list
    -> unit
    -> unit Lwt.t

  val register : unit -> Core.Container.Service.t
end
