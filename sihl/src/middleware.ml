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
module User = Middleware_user

let error = Middleware_error.m
let static = Middleware_static.m
let cookie = Middleware_cookie.m
