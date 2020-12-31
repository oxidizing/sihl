exception Crypto_failed of string
exception Csrf_token_not_found

val find : Rock.Request.t -> string
val find_opt : Rock.Request.t -> string option

val middleware
  :  ?not_allowed_handler:(Rock.Request.t -> Rock.Response.t Lwt.t)
  -> ?key:string
  -> unit
  -> Rock.Middleware.t
