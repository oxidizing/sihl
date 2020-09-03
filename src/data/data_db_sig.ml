open Data_db_core

module type SERVICE = sig
  include Core_container.SERVICE

  val create_pool : unit -> pool
  (** Create a database connection pool.
      Raises [Data_db_core.Exception]. *)

  val ctx_with_pool : unit -> Core_ctx.t
  (** Create a database connection pool and attach the pool to an empty context. *)

  val add_pool : Core_ctx.t -> Core_ctx.t
  (** Create a database connection pool and attach to provided context. *)

  val query :
    Core_ctx.t ->
    (Caqti_lwt.connection -> ('a, Caqti_error.t) Result.t Lwt.t) ->
    'a Lwt.t
  (** Run a database query.

      The context has to contain a database connection or a database connection pool.*)

  val with_connection : Core_ctx.t -> (Core_ctx.t -> 'a Lwt.t) -> 'a Lwt.t
  (** Run a database query on a single connection. Can be used to set session variables that are bound to the same connection. *)

  val atomic : Core_ctx.t -> (Core_ctx.t -> 'a Lwt.t) -> 'a Lwt.t
  (** Run a database query atomically on a connection.

The context has to contain a database connection or a database connection pool. Fetch a database connection from context if necessary to make sure, that every query runs on the same connection. *)

  val with_disabled_fk_check :
    Core.Ctx.t -> (Core_ctx.t -> 'a Lwt.t) -> 'a Lwt.t
  (** Disables foreign key checks if supported by the database.

      Use very carefully, data might become inconsistent! *)
end
