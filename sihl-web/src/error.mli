(** The error middleware should be installed in the last position. It catches,
    logs, reports and shows exceptions. *)

(** [middleware ?email_config ?reporter ?handler ()] returns a middleware that
    catches all exceptions and shows them.

    By default, it logs the exception with the request details. The response is
    either `text/html` or `application/json`, depending on the `Content-Type`
    header of the request. If SIHL_ENV is `development`, a more detailed
    debugging page is shown which makes development easier. You can override the
    error page/JSON that is shown by providing a custom error handler
    [error_handler].

    Optional email configuration [email_config] can be specified, which is a
    tuple (sender, recipient, send_function). Exceptions that are caught will be
    sent per email to [recipient] where [sender] is the sender of the email.
    Pass in the send function of the Sihl email service or provide your own
    [send_function]. An email will only be sent if SIHL_ENV is `production`.

    An optional custom reporter [reporter] can be defined. The middleware passes
    the stringified exception as first argument to the reporter callback. Use
    the reporter to implement custom error reporting. *)
val middleware
  :  ?email_config:string * string * (Sihl_contract.Email.t -> unit Lwt.t)
  -> ?reporter:(string -> unit Lwt.t)
  -> ?error_handler:(Rock.Request.t -> Rock.Response.t Lwt.t)
  -> unit
  -> Rock.Middleware.t
