module App : sig
  include module type of Core_app
end

module Configuration : sig
  include module type of Core_configuration
end

module Web : sig
  module Request : sig
    include module type of Opium.Request

    (** [bearer_token request] returns the [Bearer] token in the [Authorization]
        header. The header value has to be of form [Bearer <token>]. *)
    val bearer_token : t -> string option
  end

  module Response = Opium.Response
  module Body = Opium.Body
  module Cooke = Opium.Cookie
  module Router = Opium.Router
  module Route = Opium.Route

  module Http : sig
    include module type of Web_http
  end

  module Csrf : sig
    val find : Rock.Request.t -> string option
  end

  module Flash : sig
    val find_alert : Rock.Request.t -> string option
    val set_alert : string option -> Rock.Response.t -> Rock.Response.t
    val find_notice : Rock.Request.t -> string option
    val set_notice : string option -> Rock.Response.t -> Rock.Response.t
    val find_custom : Rock.Request.t -> string option
    val set_custom : string option -> Rock.Response.t -> Rock.Response.t
  end

  module Htmx : sig
    (** This module simplifies dealing with HTMX requests by adding type safe
        helpers to manipulate HTMX headers. Visit https://htmx.org/reference/
        for the HTMX documentation. *)

    val is_htmx : Rock.Request.t -> bool
    val current_url : Rock.Request.t -> string option
    val prompt : Rock.Request.t -> string option
    val target : Rock.Request.t -> string option
    val trigger_name : Rock.Request.t -> string option
    val trigger_req : Rock.Request.t -> string option
    val set_push : string -> Rock.Response.t -> Rock.Response.t
    val set_redirect : string -> Rock.Response.t -> Rock.Response.t
    val set_refresh : string -> Rock.Response.t -> Rock.Response.t
    val set_trigger : string -> Rock.Response.t -> Rock.Response.t
    val set_trigger_after_settle : string -> Rock.Response.t -> Rock.Response.t
    val set_trigger_after_swap : string -> Rock.Response.t -> Rock.Response.t
  end

  module Id : sig
    (** [find_opt req] returns a the id of the request [req]. *)
    val find : Rock.Request.t -> string option
  end

  module Session : sig
    (** [find ?cookie_key ?secret key request] returns the value that is
        associated to the [key] in the current session of the [request].

        [cookie_key] is the name of the session cookie. By default, the value is
        [_session].

        [secret] is the secret used to sign the session cookie. By default,
        [SIHL_SECRET] is used. *)
    val find
      :  ?cookie_key:string
      -> ?secret:string
      -> string
      -> Opium.Request.t
      -> string option

    (** [set ?cookie_key ?secret data response] returns a response that has
        [data] associated to the current session by setting the session cookie
        of the response. [set] replaces the current session.

        [cookie_key] is the name of the session cookie. By default, the value is
        [_session]. If there is a session cookie already present it gets
        replaced.

        [secret] is the secret used to sign the session cookie. By default,
        [SIHL_SECRET] is used. *)
    val set
      :  ?cookie_key:string
      -> ?secret:string
      -> (string * string) list
      -> Opium.Response.t
      -> Opium.Response.t
  end

  module Middleware : sig
    (** [csrf ?not_allowed_handler ?cookie_key ?input_name ?secret ()] returns a
        middleware that enables CSRF protection for unsafe HTTP requests.

        [not_allowed_handler] is used if an unsafe request does not pass the
        CSRF protection check. By default, [not_allowed_handler] returns an
        empty response with status 403.

        [cookie_key] is the key in the cookie under which a CSRF token will be
        stored. By default, [cookie_key] has a [__Host] prefix to increase
        cookie security. One important consequence of this prefix is, that the
        cookie cannot be sent across unencrypted (HTTP) connections. You should
        only set this argument if you know what you are doing and aware of the
        consequences.

        [input_name] is the name of the input element that is used to send the
        CSRF token. By default, the value is [_csrf]. It is recommended to use a
        [<hidden>] field in a [<form>].

        [secret] is the secret used to hash the CSRF cookie value with. By
        default, [SIHL_SECRET] is used.

        Internally, the CSRF protection is implemented as the Double Submit
        Cookie approach. *)
    val csrf
      :  ?not_allowed_handler:(Rock.Request.t -> Rock.Response.t Lwt.t)
      -> ?cookie_key:string
      -> ?input_name:string
      -> ?secret:string
      -> unit
      -> Rock.Middleware.t

    (** [error ?email_config ?reporter ?handler ()] returns a middleware that
        catches all exceptions and shows them.

        By default, it logs the exception with the request details. The response
        is either `text/html` or `application/json`, depending on the
        `Content-Type` header of the request. If SIHL_ENV is `development`, a
        more detailed debugging page is shown which makes development easier.
        You can override the error page/JSON that is shown by providing a custom
        error handler [error_handler].

        Optional email configuration [email_config] can be specified, which is a
        tuple (sender, recipient, send_function). Exceptions that are caught
        will be sent per email to [recipient] where [sender] is the sender of
        the email. Pass in the send function of the Sihl email service or
        provide your own [send_function].

        An optional custom reporter [reporter] can be defined. The middleware
        passes the request and the stringified exception to the reporter
        callback. Use the reporter to implement custom error reporting. *)
    val error
      :  ?email_config:string * string * (Contract_email.t -> unit Lwt.t)
      -> ?reporter:(Opium.Request.t -> string -> unit Lwt.t)
      -> ?error_handler:(Rock.Request.t -> Rock.Response.t Lwt.t)
      -> unit
      -> Rock.Middleware.t

    (** [flash ?cookie_key ()] returns a middleware that is used to read and
        store flash data. Flash data is session data that is valid between two
        requests. A typical use case is displaying error messages after
        submitting forms.

        [cookie_key] is the cookie name. By default, the value is [_flash].

        The flash data is stored in a separate flash cookie. The usual
        limitations apply such as a maximum of 4KB. Note that the cookie is not
        signed, don't put any data into the flash cookie that you have to trust. *)
    val flash : ?cookie_key:string -> unit -> Rock.Middleware.t

    (** [id ()] returns a middleware that reads the [X-Request-ID] headers and
        assigns it to the request.

        If no [X-Request-ID] is present, a random id is generated which is
        assigned to the request. The random id is a 64 byte long base64 encoded
        string. There is no uniqueness guarantee among ids of pending requests.
        However, generating two identical ids in a short period of time is
        highly unlikely. *)
    val id : unit -> Rock.Middleware.t

    (** [static_file ()] returns a middleware that serves static files.

        The directory that is served can be configured with [PUBLIC_DIR]. By
        default, the value is [./public].

        The path under which the file are accessible can be configured with
        [PUBLIC_URI_PREFIX]. By default, the value is [/assets]. *)
    val static_file : unit -> Rock.Middleware.t
  end
end

module Database : sig
  include Contract_database.Sig

  type config =
    { url : string
    ; pool_size : int option
    }

  val config : string -> int option -> config
  val schema : (string, string -> int option -> config, config) Conformist.t
  val used_database : unit -> Contract_database.database_type option
  val start : unit -> unit Lwt.t
  val stop : unit -> unit Lwt.t
  val lifecycle : Core_container.lifecycle
  val register : unit -> Core_container.Service.t

  module Migration = Database_migration
end

module Log : sig
  include module type of Core_log
end

module Cleaner : sig
  include module type of Core_cleaner
end

module Command : sig
  include module type of Core_command
end

module Container : sig
  include module type of Core_container
end

module Time : sig
  include module type of Core_time
end

module Schedule : sig
  include module type of Core_schedule
end

module Random : sig
  include module type of Core_random
end

module Contract : sig
  module Cache = Contract_cache
  module Database = Contract_database
  module Email = Contract_email
  module Email_template = Contract_email_template
  module Http = Contract_http
  module Migration = Contract_migration
  module Password_reset = Contract_password_reset
  module Queue = Contract_queue
  module Random = Contract_random
  module Schedule = Contract_schedule
  module Storage = Contract_storage
  module Token = Contract_token
  module User = Contract_user
end
