(** A middleware is a function that takes a {!Http.Route.handler} and returns a {!Http.Route.handler}. It is typically used to add content to  the request context that is valid only during a request. *)

type t = Middleware_core.t

type stack = Middleware_core.stack
(** A middleware stack is a list of middlewares. *)

val apply : t -> Http.Route.handler -> Http.Route.handler
(** [apply m h] applies the middleware [m] with the handler [h], so that the middleware logic wraps the handler. *)

val apply_stack : stack -> Http.Route.t -> Http.Route.t

module Clickjacking = Middleware_clickjacking
module Cookie = Middleware_cookie
module Csrf = Middleware_csrf
module Db = Middleware_db
module Error = Middleware_error
module Message = Middleware_message
module Gzip = Middleware_gzip
module Security = Middleware_security
module Static = Middleware_static
module Session = Middleware_session
module Authn = Middleware_authn

val error : unit -> t

val static :
  local_path_f:(unit -> string) ->
  uri_prefix_f:(unit -> string) ->
  ?headers:Cohttp.Header.t ->
  ?etag_of_fname:(string -> string) ->
  unit ->
  t

val cookie : unit -> t

val csrf : unit -> t

val create : name:string -> (Http.Route.handler -> Http.Route.handler) -> t
(** [create ~name (h -> h)] create a middleware with [name]. *)
