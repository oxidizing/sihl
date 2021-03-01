val find : Rock.Request.t -> Sihl_contract.User.t
val find_opt : Rock.Request.t -> Sihl_contract.User.t option
val logout : Rock.Response.t -> Rock.Response.t

val session_middleware
  :  ?key:string
  -> (user_id:string -> Sihl_contract.User.t option Lwt.t)
  -> Rock.Middleware.t

val token_middleware
  :  ?key:string
  -> ?invalid_token_handler:(Rock.Request.t -> Rock.Response.t Lwt.t)
  -> (string -> k:string -> 'a option Lwt.t)
  -> (user_id:'a -> Sihl_contract.User.t option Lwt.t)
  -> (string -> unit Lwt.t)
  -> Rock.Middleware.t
