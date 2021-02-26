exception Session_not_found

val find : string -> Opium.Request.t -> string option
val set : string * string option -> Opium.Response.t -> Opium.Response.t

val middleware
  :  ?cookie_key:string
  -> ?secret:string
  -> unit
  -> Rock.Middleware.t
