open Data_db_core

module type SERVICE = sig
  include Core_container.SERVICE

  val create_pool : unit -> (pool, string) result
  (** Create a database connection pool. *)

  val ctx_with_pool : unit -> Core_ctx.t
  (** Create a database connection pool and attach the pool to an empty context. *)

  val add_pool : Core_ctx.t -> Core_ctx.t
  (** Create a database connection pool and attach to provided context. *)

  val query :
    Core_ctx.t ->
    (Caqti_lwt.connection -> ('a, string) Lwt_result.t) ->
    ('a, string) Lwt_result.t
  (** Run a database query.

      The context has to contain a database connection or a database connection pool.*)

  val atomic :
    Core_ctx.t ->
    ?no_rollback:bool ->
    (Core_ctx.t -> ('a, 'e) Lwt_result.t) ->
    (('a, 'e) Result.t, string) Lwt_result.t
  (** Run a database query atomically on a connection.

      The context has to contain a database connection or a database connection pool. Fetch a database connection from context if necessary to make sure, that every query runs on the same connection. *)

  val single_connection :
    Core_ctx.t ->
    (Core_ctx.t -> ('a, 'e) Lwt_result.t) ->
    (('a, 'e) Result.t, string) Lwt_result.t
  (** Run a database query on a connection.

      The context has to contain a database connection or a database connection pool. Fetch a database connection from context if necessary to make sure, that every query runs on the same connection. This can be used for prepared statements.*)

  val set_fk_check : connection -> check:bool -> (unit, string) Result.t Lwt.t
  (** Disables foreign key checks if supported by the database.

      Use very carefully, data might become inconsistent! *)
end
