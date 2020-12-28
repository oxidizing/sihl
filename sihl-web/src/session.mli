val find : Rock.Request.t -> Sihl_contract.Session.t
val find_opt : Rock.Request.t -> Sihl_contract.Session.t option
val set : Sihl_contract.Session.t -> Rock.Request.t -> Rock.Request.t

val add_session_cookie
  :  string
  -> string
  -> Opium.Cookie.Signer.t
  -> Rock.Response.t
  -> Rock.Response.t

val middleware : ?cookie_name:string -> unit -> Rock.Middleware.t
