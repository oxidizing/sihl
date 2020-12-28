exception Crypto_failed of string
exception Csrf_token_not_found

val find : Rock.Request.t -> string
val find_opt : Rock.Request.t -> string option
val set : string -> Rock.Request.t -> Rock.Request.t
val create_secret : Sihl_contract.Session.t -> Sihl_contract.Token.t Lwt.t
val secret_to_token : Sihl_contract.Token.t -> string

val middleware
  :  ?not_allowed_handler:(Rock.Request.t -> Rock.Response.t)
  -> unit
  -> Rock.Middleware.t
