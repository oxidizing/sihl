type t

val create : ?body:string -> ?uri:string -> unit -> t

val ctx_of : t -> Core.Ctx.t

val update_ctx : Core.Ctx.t -> t -> t

val accepts_html : t -> bool

val require_authorization_header : t -> (Cohttp.Auth.credential, string) result

val find_in_query : string -> (string * 'a list) list -> 'a option

val query_opt : t -> string -> string option

val query : t -> string -> (string, string) result

val query2_opt : t -> string -> string -> string option * string option

val query2 :
  t -> string -> string -> (string, string) result * (string, string) result

val query3_opt :
  t ->
  string ->
  string ->
  string ->
  string option * string option * string option

val query3 :
  t ->
  string ->
  string ->
  string ->
  (string, string) result * (string, string) result * (string, string) result

val urlencoded : ?body:string -> t -> string -> (string, string) Lwt_result.t

val urlencoded2 :
  t -> string -> string -> (string * string, string) Lwt_result.t

val urlencoded3 :
  t ->
  string ->
  string ->
  string ->
  (string * string * string, string) Lwt_result.t

val param : t -> string -> string

val param2 : t -> string -> string -> string * string

val param3 : t -> string -> string -> string -> string * string * string

val require_body :
  t -> (Yojson.Safe.t -> ('a, string) result) -> ('a, string) Lwt_result.t

val of_opium : Opium_kernel.Request.t -> t
