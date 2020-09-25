val add_to_ctx : Opium_kernel.Request.t -> Core.Ctx.t -> Core.Ctx.t

val create_and_add_to_ctx :
  ?body:string -> ?uri:string -> Core.Ctx.t -> Core.Ctx.t

val accepts_html : Core.Ctx.t -> bool

val require_authorization_header :
  Core.Ctx.t -> (Cohttp.Auth.credential, string) result

val cookie_data : Core.Ctx.t -> key:string -> string option

val parse_token : Core.Ctx.t -> string option

module Query : sig
  type t = (string * string list) list

  val equal : t -> t -> bool

  val pp : Format.formatter -> t -> unit

  val show : t -> string

  val to_yojson : t -> Utils.Json.t

  val of_yojson : Utils.Json.t -> t Ppx_deriving_yojson_runtime.error_or
end

val is_get : Core.Ctx.t -> bool

val get_uri : Core.Ctx.t -> Uri.t

val get_header : Core.Ctx.t -> string -> string option

val get_query_string : Core.Ctx.t -> Query.t

val query_opt : Core.Ctx.t -> string -> string option

val query : Core.Ctx.t -> string -> (string, string) result

val query2_opt : Core.Ctx.t -> string -> string -> string option * string option

val query2 :
  Core.Ctx.t ->
  string ->
  string ->
  (string, string) result * (string, string) result

val query3_opt :
  Core.Ctx.t ->
  string ->
  string ->
  string ->
  string option * string option * string option

val query3 :
  Core.Ctx.t ->
  string ->
  string ->
  string ->
  (string, string) result * (string, string) result * (string, string) result

val urlencoded_list : ?body:string -> Core.Ctx.t -> Query.t Lwt.t

val urlencoded : ?body:string -> Core.Ctx.t -> string -> string option Lwt.t

val urlencoded2 :
  Core.Ctx.t -> string -> string -> (string * string) option Lwt.t

val urlencoded3 :
  Core.Ctx.t ->
  string ->
  string ->
  string ->
  (string * string * string) option Lwt.t

val urlencoded4 :
  Core.Ctx.t ->
  string ->
  string ->
  string ->
  string ->
  (string * string * string * string) option Lwt.t

val urlencoded5 :
  Core.Ctx.t ->
  string ->
  string ->
  string ->
  string ->
  string ->
  (string * string * string * string * string) option Lwt.t

val param : Core.Ctx.t -> string -> string option

val param2 : Core.Ctx.t -> string -> string -> (string * string) option

val param3 :
  Core.Ctx.t -> string -> string -> string -> (string * string * string) option

val param4 :
  Core.Ctx.t ->
  string ->
  string ->
  string ->
  string ->
  (string * string * string * string) option

val param5 :
  Core.Ctx.t ->
  string ->
  string ->
  string ->
  string ->
  string ->
  (string * string * string * string * string) option

val require_body :
  Core.Ctx.t ->
  (Yojson.Safe.t -> ('a, string) result) ->
  ('a, string) Lwt_result.t
