type t

val html : t

val set_body : string -> t -> t

val set_redirect : string -> t

val set_cookie : key:string -> data:string -> t -> t

val to_opium : t -> Opium_kernel.Response.t
