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

module App : sig
  include module type of Core_app
end

module Command : sig
  exception Exception of string

  type t = Core_command.t =
    { name : string
    ; usage : string option
    ; description : string
    ; fn : string list -> unit option Lwt.t
    }

  val make
    :  name:string
    -> ?help:string
    -> description:string
    -> (string list -> unit option Lwt.t)
    -> t

  val print_all : t list -> unit
  val print_help : t -> unit
  val run : t list -> string list option -> unit Lwt.t
end

module Configuration : sig
  (** A module to manage service configurations.

      An app’s configuration is everything that is likely to vary between
      deploys (staging, production, developer environments, etc).

      This includes:

      - Resource handles to the database, Memcached, and other backing services
      - Credentials to external services such as Amazon S3 or Twitter
      - Per-deploy values such as the canonical hostname for the deploy

      (Source: {{:https://12factor.net/config} https://12factor.net/config}) *)

  (** {1 Configuration} *)

  exception Exception of string

  type ('ctor, 'ty) schema = (string, 'ctor, 'ty) Conformist.t

  (** A list of key-value pairs of strings representing the configuration key
      like SMTP_HOST and a value. *)
  type data = (string * string) list

  (** The configuration contains configuration data and a configuration schema. *)
  type config = Core_configuration.config =
    { name : string
    ; description : string
    ; type_ : string
    ; default : string option
    }

  type t = Core_configuration.t

  (** [make schema data] returns a configuration containing the configuration
      [schema] and the configuration [data]. *)
  val make : ?schema:('ctor, 'ty) schema -> unit -> t

  (** {1 Storing configuration}

      Configuration might come from various sources like .env files, environment
      variables or as data provided directly to services or the app. *)

  (** [store data] stores the configuration [data]. *)
  val store : data -> unit

  (** A configuration is a list of key-value string pairs. *)

  (** {1 Reading configuration}

      Using the schema validator conformist it is easy to validate and decode
      configuration values. Conformist schemas can express a richer set of
      requirements than static types, which can be used in services to validate
      configurations at start time.

      Validating configuration when starting services can lead to run-time
      exceptions, but they occur early in the app lifecycle. This minimizes the
      feedback loop and makes sure, that services start only with valid
      configuration. *)

  (** [root_path] contains the path to the project root. It reads the value of
      [ROOT_PATH]. If that environment variable is not set, it goes up
      directories until a [.git], [.hg], [.svn], [.bzr] or [_darcs] directory is
      found. If none of these are found until [/] is reached, [None] is
      returned. *)

  val root_path : unit -> string option

  (** [env_files_path] contains the path where the env files are kept. It reads
      the value of [ENV_FILES_PATH]. If that environment variable is not set,
      [root_path] is used. If no root path can be found, [None] is returned. *)

  val env_files_path : unit -> string option

  (** [read_env_file ()] reads an [.env] file from the directory given by
      [env_files_path] and returns the key-value pairs as [data]. If [SIHL_ENV]
      is set to [test], [.env.test] is read. Otherwise [.env] is read. If the
      file doesn't exist or the directory containing the file can't be found,
      [None] is returned.

      If you just want to access configuration values, use the read functions
      instead. Every time you call [read_env_file] the file is read from disk. *)
  val read_env_file : unit -> data option

  (** [load_env_file ()] reads an [.env] file using {!read_env_file} and stores
      its contents into the environment variables. *)
  val load_env_file : unit -> unit

  (** [load ()] calls {!load_env_file} and makes sure that [SIHL_ENV] was set. *)
  val load : unit -> unit

  (** [read schema] returns the decoded, statically typed version of
      configuration [t] of the [schema]. This is used in services to
      declaratively define a valid configuration.

      The configuration data [t] is merged with the environment variable and, if
      present, an .env file.

      It fails with [Exception] and prints descriptive message of invalid
      configuration. *)
  val read : ('ctor, 'ty) schema -> 'ty

  (** [require t] raises an exception if the stored configuration doesn't
      contain the configurations provided by the list of configurations [t]. *)
  val require : ('ctor, 'ty) schema -> unit

  (** [read_string key] returns the configuration value with [key] if present.
      The function is memoized, the first call caches the returned value and
      subsequent calls are fast. *)
  val read_string : string -> string option

  (** [read_secret unit] returns the value of SIHL_SECRET if it is set. If
      SIHL_SECRET was not set, it fails in production and in testing or local
      development the value is set to "secret". *)
  val read_secret : unit -> string

  (** [read_int key] returns the configuration value with [key] if present. the
      first call caches the returned value and subsequent calls are fast. *)
  val read_int : string -> int option

  (** [read_bool key] returns the configuration value with [key] if present. the
      first call caches the returned value and subsequent calls are fast. *)
  val read_bool : string -> bool option

  (** [is_test ()] returns true if [SIHL_ENV] is [test]. This is usually the
      case when Sihl tests are executed. *)
  val is_test : unit -> bool

  (** [is_development ()] returns true if [SIHL_ENV] is [development]. This is
      usually the case when Sihl is running locally during development. *)
  val is_development : unit -> bool

  (** [is_production ()] returns true if [SIHL_ENV] is [production]. This is
      usually the case when Sihl is running in a production setting. *)
  val is_production : unit -> bool
end

module Web : sig
  (** HTTP method *)
  type meth = Web.meth =
    | Get
    | Head
    | Options
    | Post
    | Put
    | Patch
    | Delete
    | Any

  (** A [handler] returns a response given a request. *)
  type handler = Rock.Request.t -> Rock.Response.t Lwt.t

  (** A [route] has an HTTP method, a path and a handler. *)
  type route = meth * string * handler

  (** A [router] has a scope, a list of routes and a list of middlewares. A
      mounted router prefixes all routes and applies the middlewares to them. *)
  type router = Web.router =
    { scope : string
    ; routes : route list
    ; middlewares : Rock.Middleware.t list
    }

  (** [get path ?middlewares handler] returns a router with a single [GET] route
      containing the [handler]. The scope of the router is [path]. *)
  val get : string -> ?middlewares:Rock.Middleware.t list -> handler -> router

  (** [head path ?middlewares handler] returns a router with a single [HEAD]
      route containing the [handler]. The scope of the router is [path]. *)
  val head : string -> ?middlewares:Rock.Middleware.t list -> handler -> router

  (** [options path ?middlewares handler] returns a router with a single
      [OPTIONS] route containing the [handler]. The scope of the router is
      [path]. *)
  val options
    :  string
    -> ?middlewares:Rock.Middleware.t list
    -> handler
    -> router

  (** [post path ?middlewares handler] returns a router with a single [POST]
      route containing the [handler]. The scope of the router is [path]. *)
  val post : string -> ?middlewares:Rock.Middleware.t list -> handler -> router

  (** [put path ?middlewares handler] returns a router with a single [PUT] route
      containing the [handler]. The scope of the router is [path]. *)
  val put : string -> ?middlewares:Rock.Middleware.t list -> handler -> router

  (** [patch path ?middlewares handler] returns a router with a single [PATCH]
      route containing the [handler]. The scope of the router is [path]. *)
  val patch : string -> ?middlewares:Rock.Middleware.t list -> handler -> router

  (** [delete path ?middlewares handler] returns a router with a single [DELETE]
      route containing the [handler]. The scope of the router is [path]. *)
  val delete
    :  string
    -> ?middlewares:Rock.Middleware.t list
    -> handler
    -> router

  (** [any path ?middlewares handler] returns a router with a single route
      containing the [handler]. The scope of the router is [path]. This route
      matches any HTTP method. *)
  val any : string -> ?middlewares:Rock.Middleware.t list -> handler -> router

  (** [routes_of_router router] applies the middlewares, routes and the scope of
      a [router] and returns a list of routes. *)
  val routes_of_router : router -> route list

  (** [choose ?scope ?middlewares routers] returns a router by combining a list
      of [routers].

      [scope] is the new scope under which all [routers] are mounted.

      [middlewares] is an optional list of middlewares that are applied for all
      [routers]. By default, this list is empty.

      [routers] is the list of routers to combine. *)
  val choose
    :  ?scope:string
    -> ?middlewares:Rock.Middleware.t list
    -> router list
    -> router

  (** [externalize_path ?prefix path] returns a path with a [prefix] added.

      If no [prefix] is provided, [PREFIX_PATH] is used. If [PREFIX_PATH] is not
      provided, the returned path equals the provided path. *)
  val externalize_path : ?prefix:string -> string -> string

  module Request : sig
    include module type of Opium.Request

    (** [bearer_token request] returns the [Bearer] token in the [Authorization]
        header. The header value has to be of form [Bearer <token>]. *)
    val bearer_token : t -> string option
  end

  module Response = Opium.Response
  module Body = Opium.Body
  module Cookie = Opium.Cookie
  module Router = Opium.Router
  module Route = Opium.Route

  module Http : sig
    include Contract_http.Sig
  end

  module Csrf : sig
    (** [find request] returns the CSRF token of the current [request].

        Make sure that the CSRF middleware is installed. *)
    val find : Rock.Request.t -> string option
  end

  module Flash : sig
    (** [find_alert request] returns the alert stored in the flash storage of
        the current [request].

        Make sure that the flash middleware is installed.*)
    val find_alert : Rock.Request.t -> string option

    (** [set_alert alert response] returns a response with an [alert] message
        associated to it. Use [alert] to tell the user that something went
        wrong.

        Make sure that the flash middleware is installed.*)
    val set_alert : string -> Rock.Response.t -> Rock.Response.t

    (** [find_notice request] returns the notice stored in the flash storage of
        the current [request].

        Make sure that the flash middleware is installed.*)
    val find_notice : Rock.Request.t -> string option

    (** [set_notice notice response] returns a [response] with a [notice]
        message associated to it. Use [notice] to tell the user that something
        happened (successfully).

        Make sure that the flash middleware is installed.*)
    val set_notice : string -> Rock.Response.t -> Rock.Response.t

    (** [find key request] returns the string stored in the flash storage of the
        current [request] associated with [key].

        Make sure that the flash middleware is installed.*)
    val find : string -> Rock.Request.t -> string option

    (** [set flash response] returns a response with the [flash] stored. Use
        this to store arbitrary key-value values in the flash store.

        Make sure that the flash middleware is installed. *)
    val set : (string * string) list -> Rock.Response.t -> Rock.Response.t
  end

  (** This module allows you to build RESTful web pages quickly. *)
  module Rest : sig
    type action =
      [ `Index
      | `Create
      | `New
      | `Edit
      | `Show
      | `Update
      | `Destroy
      ]

    (** [form] represents a validated and decoded form. One element consists of
        [(name, input, error)].

        [name] is the schema field name and the HTML input name.

        [input] is the input of the form that was submitted, it might not be
        present. Use it to restore form values after it was submitted and
        validation or decoding failed.

        [error] is the error message of the validation or decoding. *)
    type form = (string * string option * string option) list

    (** The [SERVICE] interface has to be implemented by a CRUD service that
        drives the resource with its business logic. *)
    module type SERVICE = sig
      (** [t] is the type of the resource. *)
      type t

      (** [find id] returns [t] if it is found. *)
      val find : string -> t option Lwt.t

      (** [query ()] returns a list of [t]. *)
      val query : unit -> t list Lwt.t

      (** [insert t] inserts [t] and returns an error message that can be shown
          to the user if it fails. *)
      val insert : t -> (t, string) Result.t Lwt.t

      (** [update id t] updates the t that is found using its [id] with [t] and
          returns an error message that can be shown to the user if it fails.

          This function is similar to {!insert} and it overwrites an existing
          [t]. *)
      val update : string -> t -> (t, string) result Lwt.t

      (** [delete t] deletes [t] and returns an error message that can be shown
          to the user if it fails. *)
      val delete : t -> (unit, string) result Lwt.t
    end

    (** The [VIEW] interface needs to be implemented by a module that renders
        HTML.*)
    module type VIEW = sig
      (** [t] is the type of the resource. *)
      type t

      (** [index request csrf resources] returns a list of [resource] instances
          as HTML.

          You can access the original [request] directly if needed.

          The [csrf] token has to be included as hidden input element in the
          form. *)
      val index
        :  Rock.Request.t
        -> string
        -> t list
        -> [> Html_types.html ] Tyxml.Html.elt Lwt.t

      (** [new' request csrf form] returns a form to create new instances of the
          resource as HTML.

          You can access the original [request] directly if needed.

          [csrf] token has to be included as hidden input element in the form.

          [form] is the decoded and validated form from a previous request. It
          contains input names, submitted values and error messages. This is
          useful to display error messages on input elements or to populate the
          form with invalid input from the failed [create] request, so the user
          can fix it. *)
      val new'
        :  Rock.Request.t
        -> string
        -> form
        -> [> Html_types.html ] Tyxml.Html.elt Lwt.t

      (** [show request resource] returns the resource instance as HTML. This is
          the detail view of an instance of the resource. *)
      val show
        :  Rock.Request.t
        -> t
        -> [> Html_types.html ] Tyxml.Html.elt Lwt.t

      (** [edit request csrf form] returns a form to edit an instance of the
          resource instance as HTML.

          You can access the original [request] directly if needed.

          [csrf] token has to be included as hidden input element in the form.

          [form] is the decoded and validated form from a previous request. It
          contains input names, submitted values and error messages. This is
          useful to display error messages on input elements or to populate the
          form with invalid input from the failed [create] request, so the user
          can fix it. *)
      val edit
        :  Rock.Request.t
        -> string
        -> form
        -> t
        -> [> Html_types.html ] Tyxml.Html.elt Lwt.t
    end

    (** A module of type [CONTROLLER] can be used to create a resource with
        {!resource_of_controller}. Use a controller instead of a service and a
        view if you need low level control. *)
    module type CONTROLLER = sig
      (** [t] is the type of the resource. *)
      type t

      (** [index name request] returns a list of all resource instances as a
          response.

          [name] is the name of the resource in plural, for example [orders] or
          [users]. *)
      val index : string -> Rock.Request.t -> Rock.Response.t Lwt.t

      (** [new' ?key name request] returns a form to create instances of the
          resource as a response.

          [name] is the name of the resource in plural, for example [orders] or
          [users].

          The form data is stored in the flash storage under the [key]. By
          default, the value is [_form]. *)
      val new'
        :  ?key:string
        -> string
        -> Rock.Request.t
        -> Rock.Response.t Lwt.t

      (** [create name schema request] handles the creation of new resource
          instances and returns the creation result as a response.

          [name] is the name of the resource in plural, for example [orders] or
          [users]. *)
      val create
        :  string
        -> ('a, 'b, t) Conformist.t
        -> Rock.Request.t
        -> Rock.Response.t Lwt.t

      (** [show name request] returns a single resource instance as a response.

          [name] is the name of the resource in plural, for example [orders] or
          [users]. *)
      val show : string -> Rock.Request.t -> Rock.Response.t Lwt.t

      (** [edit ?key name request] returns a form to edit resource instances as
          a response.

          [name] is the name of the resource in plural, for example [orders] or
          [users].

          The form data is stored in the flash storage under the [key]. By
          default, the value is [_form]. *)
      val edit
        :  ?key:string
        -> string
        -> Rock.Request.t
        -> Rock.Response.t Lwt.t

      (** [update name schema request] handles the update of a resource instance
          and returns the update result as a response.

          [name] is the name of the resource in plural, for example [orders] or
          [users]. *)
      val update
        :  string
        -> ('a, 'b, t) Conformist.t
        -> Rock.Request.t
        -> Rock.Response.t Lwt.t

      (** [delete name request] handles the deletion of a resource instance and
          returns the deletion result as a response.

          [name] is the name of the resource in plural, for example [orders] or
          [users]. *)
      val delete' : string -> Rock.Request.t -> Rock.Response.t Lwt.t
    end

    (** [resource_of_service ?only name schema ~view service] returns a list of
        routers that can be combined with {!choose} that represent a resource.

        A resource [pizzas] creates following 7 routers:

        {v
        GET       /pizzas          `Index  Display a list of all pizzas
        GET       /pizzas/new      `New    Return an HTML form for creating a new pizza
        POST      /pizzas          `Create Create a new pizza
        GET       /pizzas/:id      `Show   Display a specific pizza
        GET       /pizzas/:id/edit `Edit   Return an HTML form for editing a pizza
        PATCH/PUT /pizzas/:id      `Update Update a specific pizza
        DELETE    /pizzas/:id      `Delete Delete a specific pizza
        v}

        [only] is an optional list of {!action}s. If only is set, routers are
        created only for the actions listed.

        [name] is the name of the resource. It is good practice to use plural as
        the name is used to build the resource path of the URL.

        [schema] is the conformist schema of the resource.

        [view] is the view service of type {!VIEW} of the resource. The view
        renders HTML.

        [service] is the underlying CRUD service of type {!SERVICE} of the
        resource. *)
    val resource_of_service
      :  ?only:action list
      -> string
      -> ('meta, 'ctor, 'resource) Conformist.t
      -> view:(module VIEW with type t = 'resource)
      -> (module SERVICE with type t = 'resource)
      -> router list

    (** [resource_of_controller ?only name schema controller] returns the same
        list of routers as {!resource_of_service}. [resource_of_controller]
        takes one module of type {!CONTROLLER} instead of a view and a service.

        If you implement your own controller you have to do all the wiring
        yourself, but you gain more control. *)
    val resource_of_controller
      :  ?only:action list
      -> string
      -> ('meta, 'ctor, 'resource) Conformist.t
      -> (module CONTROLLER with type t = 'resource)
      -> router list

    (** [find_form name form] returns the [(value, error)] of a [form] input
        element with the [name].

        The [value] is the submitted value of the input element. The value is
        set even if the submitted form failed to decode or validate. Use the
        submitted values to populate the form that can be fixed and re-submitted
        by the user

        The [error] message comes from either the decoding, validation or CRUD
        service. It can be shown to the user. *)
    val find_form : string -> form -> string option * string option
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
    (** [find_opt req] returns a the id of the request [req].

        Make sure that the id middleware is installed. *)
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

    (** [migration fetch_pending_migrations] returns a middleware that shows a
        warning page in case there are pending migrations. The middleware shows
        a generic internal error page if [SIHL_ENV] is [production] to not leak
        information.

        [fetch_pending_migrations] is a function that returns a list of pending
        migrations. Use the [pending_migration] function of the migration
        service. If the returned list is empty, there are no pending migrations.*)
    val migration : (unit -> (string * int) list Lwt.t) -> Rock.Middleware.t

    (** [trailing_slash ()] returns a middleware that removes all trailing
        slashes [/] from the request URI path. Apply it globally (before the
        router) to make sure that a path [/foo/bar/] matches the route
        [/foo/bar].

        Multiple trailing slashes are removed. *)
    val trailing_slash : unit -> Rock.Middleware.t

    (** [static_file ()] returns a middleware that serves static files.

        The directory that is served can be configured with [PUBLIC_DIR]. By
        default, the value is [./public].

        The path under which the file are accessible can be configured with
        [PUBLIC_URI_PREFIX]. By default, the value is [/assets]. *)
    val static_file : unit -> Rock.Middleware.t
  end
end

module Log : sig
  include module type of Core_log
end

module Cleaner : sig
  include module type of Core_cleaner
end

module Container : sig
  (** A module to manage the service container and service lifecycles.

      The service container knows how to start services in the right order by
      respecting the defined dependencies. Use it to implement your own
      services. *)

  (** {1 Lifecycle}

      Every service has a lifecycle, meaning it can be started and stopped. **)

  type lifecycle = Core_container.lifecycle =
    { name : string
    ; dependencies : unit -> lifecycle list
    ; start : unit -> unit Lwt.t
    ; stop : unit -> unit Lwt.t
    }

  val create_lifecycle
    :  ?dependencies:(unit -> lifecycle list)
    -> ?start:(unit -> unit Lwt.t)
    -> ?stop:(unit -> unit Lwt.t)
    -> string
    -> lifecycle

  (** {1 Service}

      A service has a [start] and [stop] function and a lifecycle. **)

  module Service : sig
    module type Sig = sig
      val lifecycle : lifecycle
    end

    type t = Core_container.Service.t =
      { lifecycle : lifecycle
      ; configuration : Configuration.t
      ; commands : Command.t list
      ; server : bool
      }

    val commands : t -> Command.t list
    val configuration : t -> Configuration.t

    val create
      :  ?commands:Command.t list
      -> ?configuration:Configuration.t
      -> ?server:bool
      -> lifecycle
      -> t

    val server : t -> bool
    val start : t -> unit Lwt.t
    val stop : t -> unit Lwt.t
    val name : t -> string
  end

  (** [start_services services] starts a list of [services]. The order does not
      matter as the services are started in the order of their dependencies. (No
      service is started before its dependency) *)
  val start_services : Service.t list -> lifecycle list Lwt.t

  (** [stop_services ctx services] stops a list of [services] with a context
      [ctx]. The order does not matter as the services are stopped in the order
      of their dependencies. (No service is stopped after its dependency) *)
  val stop_services : Service.t list -> unit Lwt.t

  module Map : sig
    type 'a t
  end

  val collect_all_lifecycles : lifecycle list -> lifecycle Map.t
  val top_sort_lifecycles : lifecycle list -> lifecycle list
  val unpack : string -> ?default:'a -> 'a option ref -> 'a
end

module Database : sig
  include Contract_database.Sig

  val used_database : unit -> Contract_database.database_type option
  val start : unit -> unit Lwt.t
  val stop : unit -> unit Lwt.t
  val lifecycle : Container.lifecycle
  val register : unit -> Container.Service.t

  module Migration = Database_migration
end

module Time : sig
  include module type of Core_time
end

module Schedule : sig
  include module type of Core_schedule
end

module Random : sig
  (** [base64 n] returns a Base64 encoded string containing [n] random bytes. *)
  val base64 : int -> string

  (** [bytes n] returns a byte sequence as string with [n] random bytes. In most
      cases you want to use {!base64} to get a string that can be used safely in
      most web contexts.*)
  val bytes : int -> string
end
