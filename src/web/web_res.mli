type body = String of string | File_path of string

type t

val pp : Format.formatter -> t -> unit

val equal : t -> t -> bool

val file : string -> Web_core.content_type -> t
(** file [file_path] [content_type] streams a file at [file_path] as HTTP response with the Content-Type header set to [content_type]. *)

val html : t

val json : t

val redirect : string -> t

val redirect_path : t -> string option

val body : t -> body option

val set_body : string -> t -> t

val headers : t -> Web_core.headers

val set_headers : Web_core.headers -> t -> t

val content_type : t -> Web_core.content_type

val set_content_type : Web_core.content_type -> t -> t

val opium_res : t -> Opium_kernel.Response.t option

val set_opium_res : Opium_kernel.Response.t -> t -> t

val cookies : t -> (string * string) list

val set_cookie : key:string -> data:string -> t -> t

val status : t -> int

val set_status : int -> t -> t
