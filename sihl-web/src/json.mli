exception Json_body_not_found

val find : Rock.Request.t -> Yojson.Safe.t
val find_opt : Rock.Request.t -> Yojson.Safe.t option
val set : Yojson.Safe.t -> Rock.Request.t -> Rock.Request.t
val middleware : Rock.Middleware.t
