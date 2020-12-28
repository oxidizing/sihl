exception Flash_not_found

val find : Rock.Request.t -> string option
val set : string option -> Rock.Response.t -> Rock.Response.t
val middleware : ?flash_store_name:string -> unit -> Rock.Middleware.t
