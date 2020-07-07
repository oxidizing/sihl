type t

val html : t

val set_body : string -> t -> t

val set_opium_res : Opium_kernel.Response.t -> t -> t

val set_redirect : string -> t

val set_cookie : key:string -> data:string -> t -> t

val set_status : int -> t -> t

val to_opium : t -> Opium_kernel.Response.t
