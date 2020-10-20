open Model

module type SERVICE = sig
  include Core.Container.Service.Sig

  (** Creates and returns a database connection pool. Re-uses an already created pool.
      Raises [Data_db_core.Exception]. *)
  val fetch_pool : unit -> pool

  (** Run a database query.

      The context has to contain a database connection or a database connection pool.*)
  val query
    :  Core.Ctx.t
    -> (Caqti_lwt.connection -> ('a, Caqti_error.t) Result.t Lwt.t)
    -> 'a Lwt.t

  (** Run a database query atomically on a connection.

      The context has to contain a database connection or a database connection pool.
      Fetch a database connection from context if necessary to make sure, that every query
      runs on the same connection. *)
  val atomic : Core.Ctx.t -> (Core.Ctx.t -> 'a Lwt.t) -> 'a Lwt.t

  (** Disables foreign key checks if supported by the database.

      Use very carefully, data might become inconsistent! *)
  val with_disabled_fk_check : Core.Ctx.t -> (Core.Ctx.t -> 'a Lwt.t) -> 'a Lwt.t

  val configure : Core.Configuration.data -> Core.Container.Service.t
end
