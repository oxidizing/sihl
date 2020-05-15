module Flash = Middleware_flash
module Error = Middleware_error
module Static = Middleware_static
module Cookie = Middleware_cookie
module Db = Middleware_db

let flash () = Flash.m

let error () = Error.m

let static = Static.m

let cookie () = Cookie.m

let db = Db.m
