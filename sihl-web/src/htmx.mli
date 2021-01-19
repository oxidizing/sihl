(** This module simplifies dealing with htmx requests in a type safe way. Visit
    https://htmx.org/reference/ for the htmx documentation. *)

exception Exception

val is_htmx : Rock.Request.t -> bool
val current_url : Rock.Request.t -> string
val prompt : Rock.Request.t -> string option
val target : Rock.Request.t -> string option
val trigger_name : Rock.Request.t -> string option
val trigger_req : Rock.Request.t -> string option
val set_push : string option -> Rock.Response.t -> Rock.Response.t
val set_redirect : string option -> Rock.Response.t -> Rock.Response.t
val set_refresh : string option -> Rock.Response.t -> Rock.Response.t
val set_trigger : string option -> Rock.Response.t -> Rock.Response.t

val set_trigger_after_settle
  :  string option
  -> Rock.Response.t
  -> Rock.Response.t

val set_trigger_after_swap : string option -> Rock.Response.t -> Rock.Response.t

val add_htmx_resp_header
  :  string
  -> string option
  -> Rock.Response.t
  -> Rock.Response.t

val middleware : Rock.Middleware.t
