type body = (string * string list) list

exception Parsed_body_not_found

val find_all : Rock.Request.t -> body
val find : string -> Rock.Request.t -> string option
val consume : Rock.Request.t -> string -> Rock.Request.t * string option
val middleware : Rock.Middleware.t
