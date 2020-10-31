(** A middleware is a function that takes a {!Http.Route.handler} and returns a
    {!Http.Route.handler}. It is typically used to add content to the request context that
    is valid only during a request. *)

module Clickjacking = Middleware_clickjacking
module Cookie = Middleware_cookie
module Csrf = Middleware_csrf
module Error = Middleware_error
module Message = Middleware_message
module Gzip = Middleware_gzip
module Security = Middleware_security
module Static = Middleware_static
module Session = Middleware_session
module Authn = Middleware_authn

val error : unit -> Opium_kernel.Rock.Middleware.t

val static
  :  local_path_f:(unit -> string)
  -> uri_prefix_f:(unit -> string)
  -> ?headers:Cohttp.Header.t
  -> ?etag_of_fname:(string -> string)
  -> unit
  -> Opium_kernel.Rock.Middleware.t

val cookie : unit -> Opium_kernel.Rock.Middleware.t
