exception Flash_not_found

val find_alert : Rock.Request.t -> string option
val set_alert : string option -> Rock.Response.t -> Rock.Response.t
val find_notice : Rock.Request.t -> string option
val set_notice : string option -> Rock.Response.t -> Rock.Response.t
val find_custom : Rock.Request.t -> string option
val set_custom : string option -> Rock.Response.t -> Rock.Response.t
val middleware : ?flash_store_name:string -> unit -> Rock.Middleware.t
