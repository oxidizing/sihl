open Opium.Std

(** {{1} Type aliases for clearer documentation and explication} *)

type 'err caqti_conn_pool =
  (Caqti_lwt.connection, ([> Caqti_error.connect ] as 'err)) Caqti_lwt.Pool.t

type ('res, 'err) query =
  Caqti_lwt.connection -> ('res, ([< Caqti_error.t ] as 'err)) result Lwt.t

type 'a db_result = ('a, Caqti_error.t) Lwt_result.t

type connection = (module Caqti_lwt.CONNECTION)

(** {{1} API for the Opium app database middleware }*)

val middleware : App.builder

val clean : (connection -> unit db_result) list -> (unit, string) Lwt_result.t

val request_with_connection : Opium.Std.Request.t -> Opium.Std.Request.t Lwt.t

val query_db_with_trx :
  Opium_kernel.Rock.Request.t ->
  (connection -> 'a db_result) ->
  ('a, string) result Lwt.t

val query_db_with_trx_exn :
  Opium_kernel.Rock.Request.t -> (connection -> 'a db_result) -> 'a Lwt.t

val query_db :
  Opium_kernel.Rock.Request.t ->
  (connection -> 'a db_result) ->
  ('a, string) result Lwt.t

val query_db_exn :
  ?message:string ->
  Opium_kernel.Rock.Request.t ->
  (connection -> 'a db_result) ->
  'a Lwt.t

(** {{1} API for database migrations } *)

module Migrate : sig
  (** Interface for executing database migrations *)

  type migration_error = Caqti_error.t

  type migration_operation =
    Caqti_lwt.connection -> unit -> (unit, migration_error) result Lwt.t

  type migration_step = string * migration_operation

  type migration = string * migration_step list

  module MariaDbRepository : Contract.Migration.REPOSITORY

  module PostgresRepository : Contract.Migration.REPOSITORY

  val execute : migration list -> (unit, string) result Lwt.t
  (** [execute steps] is [Ok ()] if all the migration tasks in [steps] can be
      executed or [Error err] where [err] explains the reason for failure. *)
end
