type headers = (string * string) list

type t

val html : t

val content : string -> t -> t

val redirect : string -> t

val set_cookie :
  key:string ->
  data:string ->
  Opium_kernel.Response.t ->
  Opium_kernel.Response.t
