(** This is the main module. Use {!App} app to create Sihl apps. *)
module App : sig
  include module type of Core_app
end

(** Use {!Configuration} to read app configuration from environment variables or
    .env files. Sihl services require a valid configuration at start-up time,
    they won't start if the configuration they need is not available. *)
module Configuration : sig
  include module type of Core_configuration
end

(** Use {!Web} to setup routers, handlers and middlewares to deal with HTTP
    requests. *)
module Web : sig
  module Request = Opium.Request
  module Response = Opium.Response
  module Body = Opium.Body
  module Router = Opium.Router
  module Route = Opium.Route

  module Http : sig
    include module type of Web_http
  end

  module Authentication : sig
    val login
      :  email:string
      -> password:string
      -> Rock.Response.t
      -> Rock.Response.t
  end

  module Bearer_token : sig
    val find : Rock.Request.t -> string
    val find_opt : Rock.Request.t -> string option
    val set : string -> Rock.Request.t -> Rock.Request.t
  end

  module Csrf : sig
    exception Csrf_token_not_found

    val find : Rock.Request.t -> string
  end

  module Flash : sig
    exception Flash_not_found

    val find_alert : Rock.Request.t -> string option
    val set_alert : string option -> Rock.Response.t -> Rock.Response.t
    val find_notice : Rock.Request.t -> string option
    val set_notice : string option -> Rock.Response.t -> Rock.Response.t
    val find_custom : Rock.Request.t -> string option
    val set_custom : string option -> Rock.Response.t -> Rock.Response.t
  end

  module Form : sig
    type body = (string * string list) list

    val pp : Format.formatter -> body -> unit

    exception Parsed_body_not_found

    val find_all : Rock.Request.t -> body
    val find : string -> Rock.Request.t -> string option
    val consume : Rock.Request.t -> string -> Rock.Request.t * string option
  end

  module Htmx : sig
    (** This module simplifies dealing with htmx requests in a type safe way.
        Visit https://htmx.org/reference/ for the htmx documentation. *)

    exception Exception

    val is_htmx : Rock.Request.t -> bool
    val current_url : Rock.Request.t -> string
    val prompt : Rock.Request.t -> string option
    val target : Rock.Request.t -> string option
    val trigger_name : Rock.Request.t -> string option
    val trigger_req : Rock.Request.t -> string option
    val set_push : string option -> Rock.Response.t -> Rock.Response.t
    val set_redirect : string option -> Rock.Response.t -> Rock.Response.t
    val set_refresh : string option -> Rock.Response.t -> Rock.Response.t
    val set_trigger : string option -> Rock.Response.t -> Rock.Response.t

    val set_trigger_after_settle
      :  string option
      -> Rock.Response.t
      -> Rock.Response.t

    val set_trigger_after_swap
      :  string option
      -> Rock.Response.t
      -> Rock.Response.t

    val add_htmx_resp_header
      :  string
      -> string option
      -> Rock.Response.t
      -> Rock.Response.t
  end

  module Id : sig
    exception Id_not_found

    val find : Rock.Request.t -> string
    val find_opt : Rock.Request.t -> string option
    val set : string -> Rock.Request.t -> Rock.Request.t
  end

  module Json : sig
    exception Json_body_not_found

    val find : Rock.Request.t -> Yojson.Safe.t
    val find_opt : Rock.Request.t -> Yojson.Safe.t option
    val set : Yojson.Safe.t -> Rock.Request.t -> Rock.Request.t
  end

  module Session : sig
    exception Session_not_found

    val find : string -> Opium.Request.t -> string option
    val set : string * string option -> Opium.Response.t -> Opium.Response.t
  end

  module User : sig
    val find : Rock.Request.t -> Contract_user.t
    val find_opt : Rock.Request.t -> Contract_user.t option
    val logout : Rock.Response.t -> Rock.Response.t
  end

  module Middleware : sig
    val authentication_session
      :  ?key:String.t
      -> ?error_handler:('a -> Response.t Lwt.t)
      -> (email:string -> password:string -> (Contract_user.t, 'a) result Lwt.t)
      -> Rock.Middleware.t

    val authentication_token
      :  ?key:string
      -> ?error_handler:('a -> Response.t Lwt.t)
      -> (email:string -> password:string -> (Contract_user.t, 'a) result Lwt.t)
      -> ((string * string) list -> string Lwt.t)
      -> Rock.Middleware.t

    val authorization_user : login_path_f:(unit -> string) -> Rock.Middleware.t

    val authorization_admin
      :  login_path_f:(unit -> string)
      -> (Contract_user.t -> bool)
      -> Rock.Middleware.t

    val bearer_token : Rock.Middleware.t

    (** [csrf ?not_allowed_handler ?cookie_key ?secret ()] returns a middleware
        that enables CSRF protection for unsafe HTTP requests.

        [not_allowed_handler] is used if an unsafe request does not pass the
        CSRF protection check. By default, [not_allowed_handler] returns an
        empty response with status 403.

        [cookie_key] is the key in the cookie under which a CSRF token will be
        stored. By default, [cookie_key] has a [__Host] prefix to increase
        cookie security. One important consequence of this prefix is, that the
        cookie cannot be sent across unencrypted (HTTP) connections. You should
        only set this argument if you know what you are doing and aware of the
        consequences.

        [secret] is the secret used to hash the CSRF cookie value with. By
        default, [SIHL_SECRET] is used.

        Internally, the CSRF protection is implemented as the Double Submit
        Cookie approach. *)

    val csrf
      :  ?not_allowed_handler:(Rock.Request.t -> Rock.Response.t Lwt.t)
      -> ?cookie_key:string
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
        provide your own [send_function]. An email will only be sent if SIHL_ENV
        is `production`.

        An optional custom reporter [reporter] can be defined. The middleware
        passes the stringified exception as first argument to the reporter
        callback. Use the reporter to implement custom error reporting. *)
    val error
      :  ?email_config:string * string * (Contract_email.t -> unit Lwt.t)
      -> ?reporter:(string -> unit Lwt.t)
      -> ?error_handler:(Rock.Request.t -> Rock.Response.t Lwt.t)
      -> unit
      -> Rock.Middleware.t

    val flash : ?cookie_key:string -> unit -> Rock.Middleware.t
    val form : Rock.Middleware.t
    val htmx : Rock.Middleware.t
    val id : Rock.Middleware.t
    val json : Rock.Middleware.t

    val session
      :  ?cookie_key:string
      -> ?secret:string
      -> unit
      -> Rock.Middleware.t

    val static_file : unit -> Rock.Middleware.t

    val user_session
      :  ?key:string
      -> (user_id:string -> Contract_user.t option Lwt.t)
      -> Rock.Middleware.t

    val user_token
      :  ?key:string
      -> ?invalid_token_handler:(Rock.Request.t -> Rock.Response.t Lwt.t)
      -> (string -> k:string -> 'a option Lwt.t)
      -> (user_id:'a -> Contract_user.t option Lwt.t)
      -> (string -> unit Lwt.t)
      -> Rock.Middleware.t
  end
end

(** Use {!Database} to handle connection pooling, migrations and to query your
    database. *)
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

(** Use {!Log} to set up a logger for your Sihl app. This module can not be used
    to actually log, use {!Logs} for that. *)
module Log : sig
  include module type of Core_log
end

(** Use {!Cleaner} to clean persisted service state. This is useful for cleaning
    the state before running tests. *)
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
