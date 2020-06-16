type content_type = Html | Json

val content_type : content_type -> string

val fail : Core_error.t -> exn

module Msg : sig
  type t = { msg : string }

  val to_yojson : t -> Core_json.t

  val of_yojson : Core_json.t -> t Ppx_deriving_yojson_runtime.error_or

  val ok_string : string

  val msg_string : string -> string
end

val code_of_error : Core_err.Error.t -> Cohttp.Code.status_code

type headers = (string * string) list

type change_session = Nothing | SetSession of string | EndSession

type t = {
  content_type : content_type;
  body : string option;
  headers : headers;
  status : int;
  session : change_session;
  file : string option;
}

val status : int -> t -> t

val header : string -> string -> t -> t

val headers : headers -> t -> t

val redirect : string -> t -> t

val start_session : string -> t -> t

val stop_session : t -> t

val empty : t

val json : string -> t

val html : string -> t

val file : string -> t

val to_cohttp : t -> Opium_kernel.Response.t
