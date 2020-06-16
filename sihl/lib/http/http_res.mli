type content_type = Html | Json

val content_type : content_type -> string

val fail : Core.Error.t -> exn

val of_exn : exn -> Core.Error.t

val try_run :
  (unit -> Opium_kernel.Response.t Lwt.t) ->
  (Opium_kernel.Response.t, Core.Error.t) result Lwt.t

val code_of_error : Core.Error.t -> Cohttp.Code.status_code

val error_to_msg : Core.Error.t -> string

module Msg : sig
  type t = { msg : string }

  val to_yojson : t -> Core_json.t

  val of_yojson : Core_json.t -> t Ppx_deriving_yojson_runtime.error_or

  val ok_string : string

  val msg_string : string -> string
end

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
