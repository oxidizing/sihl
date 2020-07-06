module type SERVICE = sig
  val on_bind : Core_ctx.t -> (unit, string) Lwt_result.t

  val on_start : Core_ctx.t -> (unit, string) Lwt_result.t

  val on_stop : Core_ctx.t -> (unit, string) Lwt_result.t
end

type 'a key

type binding

val create_key : string -> 'a key

val fetch_service : 'a key -> 'a option

val fetch_service_exn : 'a key -> 'a

val create_binding : 'a key -> 'a -> (module SERVICE) -> binding

val register : binding -> unit

val set_initialized : unit -> unit

val bind_services : Core_ctx.t -> binding list -> (unit, string) Lwt_result.t

val start_services : Core_ctx.t -> (unit, string) Lwt_result.t
