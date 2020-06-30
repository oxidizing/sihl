type 'a key

type binding

val create_key : string -> 'a key

val fetch_service : 'a key -> 'a option

val fetch_service_exn : 'a key -> 'a

val create_binding : 'a key -> 'a -> (module Sig.SERVICE) -> binding

val register : binding -> unit

val set_initialized : unit -> unit

val bind : Core_ctx.t -> binding list -> (unit, string) Lwt_result.t
