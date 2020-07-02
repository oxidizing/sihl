type pool = (Caqti_lwt.connection, Caqti_error.t) Caqti_lwt.Pool.t

val ctx_key_pool : pool Core_ctx.key

val ctx_add_pool : pool -> Core_ctx.t -> Core_ctx.t

type connection = (module Caqti_lwt.CONNECTION)

val ctx_key_connection : connection Core_ctx.key

val middleware_key_connection : connection Opium.Hmap.key

val create_pool : unit -> (pool, string) result

val ctx_with_pool : unit -> Core_ctx.t

val add_pool : Core_ctx.t -> Core_ctx.t

val query_connection :
  connection ->
  (connection -> ('a, Caqti_error.t) Lwt_result.t) ->
  ('a, string) Lwt_result.t

val query :
  Core_ctx.t ->
  (Caqti_lwt.connection -> ('a, string) Lwt_result.t) ->
  ('a, string) Lwt_result.t

val atomic :
  Core_ctx.t ->
  (Core_ctx.t -> ('a, 'e) Lwt_result.t) ->
  (('a, 'e) Result.t, string) Lwt_result.t

val set_fk_check : connection -> check:bool -> (unit, string) Result.t Lwt.t
