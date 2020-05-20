module Clickjacking = Middleware_clickjacking
module Cookie = Middleware_cookie
module Csrf = Middleware_csrf
module Db = Middleware_db
module Error = Middleware_error
module Flash = Middleware_flash
module Gzip = Middleware_gzip
module Security = Middleware_security
module Static = Middleware_static

let flash () = Flash.m

let error () = Error.m

let static = Static.m

let cookie () = Cookie.m

let db = Db.m
