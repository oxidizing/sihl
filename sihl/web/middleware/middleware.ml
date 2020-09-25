type t = Middleware_core.t

type stack = Middleware_core.stack

let apply = Middleware_core.apply

let apply_stack = Middleware_core.apply_stack

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

let error = Middleware_error.m

let static = Middleware_static.m

let cookie = Middleware_cookie.m

let csrf = Middleware_csrf.m

let create = Middleware_core.create
