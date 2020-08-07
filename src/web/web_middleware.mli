type t = Web_middleware_core.t

type stack = Web_middleware_core.stack

val apply : t -> Web_route.t -> Web_route.t

val apply_stack : stack -> Web_route.t -> Web_route.t

module Clickjacking = Web_middleware_clickjacking
module Cookie = Web_middleware_cookie
module Csrf = Web_middleware_csrf
module Db = Web_middleware_db
module Error = Web_middleware_error
module Message = Web_middleware_message
module Gzip = Web_middleware_gzip
module Security = Web_middleware_security
module Static = Web_middleware_static
module Session = Web_middleware_session
module Authn = Web_middleware_authn

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

val create : name:string -> (Web_route.handler -> Web_route.handler) -> t
