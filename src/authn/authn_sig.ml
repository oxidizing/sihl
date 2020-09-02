module type SERVICE = sig
  include Core_container.SERVICE

  val find_user_in_session_opt : Core.Ctx.t -> User.t option Lwt.t
  (** Find currently logged in user in the current context.

      Make sure to call [authenticate_session] before or apply the required session and authentication middlewares. *)

  val find_user_in_session : Core.Ctx.t -> User.t Lwt.t
  (** Find currently logged in user in the current context.

      Make sure to call [authenticate_session] before or apply the required session and authentication middlewares. *)

  val authenticate_session : Core.Ctx.t -> User.t -> unit Lwt.t
  (** Assign a user to the current anonymous session.

      Use [authenticate_session ctx user] to log in a [user]. If a user is already assigned to session, replace the user. *)

  val unauthenticate_session : Core.Ctx.t -> unit Lwt.t
  (** Log user out.

      Remove user from current session so that session is anonymous again. *)
end
