open Sihl_type

exception Exception of string

module type Sig = sig
  include Sihl_core.Container.Service.Sig

  (** Find currently logged in user in the current context.

      Make sure to call [authenticate_session] before or apply the required session and
      authentication middlewares. *)
  val find_user_in_session_opt : Session.t -> User.t option Lwt.t

  (** Find currently logged in user in the current context.

      Make sure to call [authenticate_session] before or apply the required session and
      authentication middlewares. *)
  val find_user_in_session : Session.t -> User.t Lwt.t

  (** Assign a user to the current anonymous session.

      Use [authenticate_session ctx user] to log in a [user]. If a user is already
      assigned to session, replace the user. *)
  val authenticate_session : User.t -> Session.t -> unit Lwt.t

  (** Log user out.

      Remove user from current session so that session is anonymous again. *)
  val unauthenticate_session : Session.t -> unit Lwt.t

  val register : unit -> Sihl_core.Container.Service.t
end
