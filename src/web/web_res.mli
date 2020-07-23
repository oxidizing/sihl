type t

val pp : Format.formatter -> t -> unit

val equal : t -> t -> bool

val html : t

val json : t

val redirect : string -> t

val set_body : string -> t -> t

val set_content_type : Web_core.content_type -> t -> t

val set_opium_res : Opium_kernel.Response.t -> t -> t

val set_cookie : key:string -> data:string -> t -> t

val set_status : int -> t -> t

val to_opium : t -> Opium_kernel.Response.t
