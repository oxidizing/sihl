type body = (string * string list) list

val body_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> body
val sexp_of_body : body -> Ppx_sexp_conv_lib.Sexp.t

exception Parsed_body_not_found

val key : body Rock.Context.key
val find_all : Rock.Request.t -> body
val find : string -> Rock.Request.t -> string option
val consume : Rock.Request.t -> string -> Rock.Request.t * string option
val middleware : Rock.Middleware.t
