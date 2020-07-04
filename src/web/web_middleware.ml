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

let flash = Flash.m

let error = Error.m

let static = Static.m

let cookie = Cookie.m

let db = Db.m

let session = Session.m

let csrf = Csrf.m

(* TODO: Evaluate use own middleware abstraction? *)
(* type t = Web_req.t -> Web_res.t Lwt.t -> Web_req.t -> Web_res.t Lwt.t *)
type t = unit -> Opium_kernel.Rock.Middleware.t
