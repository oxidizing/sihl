exception Id_not_found

val find : Rock.Request.t -> string
val find_opt : Rock.Request.t -> string option
val set : string -> Rock.Request.t -> Rock.Request.t
val middleware : Rock.Middleware.t
