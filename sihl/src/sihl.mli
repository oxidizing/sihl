module App : sig
  include module type of Core_app
end

module Configuration : sig
  include module type of Core_configuration
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
