type t

type stack = t list

val apply_stack : stack -> Web_route.t -> Web_route.t

module Clickjacking = Web_middleware_clickjacking
module Cookie = Web_middleware_cookie
module Csrf = Web_middleware_csrf
module Db = Web_middleware_db
module Error = Web_middleware_error
module Flash = Web_middleware_flash
module Gzip = Web_middleware_gzip
module Security = Web_middleware_security
module Static = Web_middleware_static
module Session = Web_middleware_session
module Authn = Web_middleware_authn

val flash : unit -> t

val error : unit -> t

(* val static : unit -> t *)

(* val cookie : unit -> t *)

(* val db : unit -> t *)

(* val session : unit -> t *)

(* val csrf : unit -> t *)
