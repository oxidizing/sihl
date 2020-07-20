type t = Web_middleware_core.t

type stack = Web_middleware_core.stack

let apply = Web_middleware_core.apply

let apply_stack = Web_middleware_core.apply_stack

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

let error = Web_middleware_error.m

let static = Web_middleware_static.m

let cookie = Web_middleware_cookie.m

let csrf = Web_middleware_csrf.m

let create = Web_middleware_core.create
