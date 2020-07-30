open Data_db_core

module type SERVICE = sig
  include Core_container.SERVICE

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
    ?no_rollback:bool ->
    (Core_ctx.t -> ('a, 'e) Lwt_result.t) ->
    (('a, 'e) Result.t, string) Lwt_result.t

  val single_connection :
    Core_ctx.t ->
    (Core_ctx.t -> ('a, 'e) Lwt_result.t) ->
    (('a, 'e) Result.t, string) Lwt_result.t

  val set_fk_check : connection -> check:bool -> (unit, string) Result.t Lwt.t
end
