type t

val ctx_of : t -> Core_ctx.t

val find_in_query : string -> (string * 'a list) list -> 'a option

val urlencoded : ?body:string -> t -> string -> (string, string) Lwt_result.t

val urlencoded2 :
  t -> string -> string -> (string * string, string) Lwt_result.t

val urlencoded3 :
  t ->
  string ->
  string ->
  string ->
  (string * string * string, string) Lwt_result.t
