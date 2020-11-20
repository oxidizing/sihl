open Sihl_type

module type Sig = sig
  include Sihl_core.Container.Service.Sig

  val fetch_entry : Session.t -> Message_entry.t option Lwt.t
  val find_current : Session.t -> Message.t option Lwt.t
  val set_next : Session.t -> Message.t -> unit Lwt.t
  val rotate : Session.t -> Message.t option Lwt.t
  val current : Session.t -> Message.t option Lwt.t

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

  val register : unit -> Sihl_core.Container.Service.t
end
