val find : Rock.Request.t -> Sihl_contract.User.t
val find_opt : Rock.Request.t -> Sihl_contract.User.t option
val logout : Rock.Response.t -> Rock.Response.t
val session_middleware : ?key:string -> unit -> Rock.Middleware.t

val token_middleware
  :  ?invalid_token_handler:(Rock.Request.t -> Rock.Response.t Lwt.t)
  -> unit
  -> Rock.Middleware.t
