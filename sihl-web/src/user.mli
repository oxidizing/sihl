val find : Rock.Request.t -> Sihl_contract.User.t
val find_opt : Rock.Request.t -> Sihl_contract.User.t option
val set : Sihl_contract.User.t -> Rock.Request.t -> Rock.Request.t
val login : Sihl_contract.User.t -> Rock.Response.t -> Rock.Response.t
val logout : Rock.Response.t -> Rock.Response.t
val session_middleware : ?key:string -> unit -> Rock.Middleware.t
val token_middleware : Rock.Middleware.t
