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
(** [middleware app] equips the [app] with the database pool needed by the
    functions in [Update] and [Get]. It cannot (and should not) be accessed
    except through the API in this module. *)

val middleware_connection : App.builder

val query_db :
  Opium_kernel.Rock.Request.t ->
  (connection -> 'a db_result) ->
  ('a, string) result Lwt.t

(** {{1} API for database migrations } *)

module Migrate : sig
  (** Interface for executing database migrations *)

  type 'a migration_error =
    [< Caqti_error.t > `Connect_failed
    `Connect_rejected
    `Decode_rejected
    `Encode_failed
    `Encode_rejected
    `Post_connect
    `Request_failed
    `Request_rejected
    `Response_failed
    `Response_rejected ]
    as
    'a

  type 'a migration_operation =
    Caqti_lwt.connection -> unit -> (unit, 'a migration_error) result Lwt.t

  type 'a migration_step = string * 'a migration_operation

  type 'a migration = string * 'a migration_step list

  val execute : _ migration list -> (unit, string) result Lwt.t
  (** [execute steps] is [Ok ()] if all the migration tasks in [steps] can be
      executed or [Error err] where [err] explains the reason for failure. *)
end
