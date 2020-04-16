open Opium.Std

(** {{1} Type aliases for clearer documentation and explication} *)

type 'err caqti_conn_pool =
  (Caqti_lwt.connection, ([> Caqti_error.connect ] as 'err)) Caqti_lwt.Pool.t

type ('res, 'err) query =
  Caqti_lwt.connection -> ('res, ([< Caqti_error.t ] as 'err)) result Lwt.t

(** {{1} API for the Opium app database middleware }*)

val middleware : App.builder
(** [middleware app] equips the [app] with the database pool needed by the
    functions in [Update] and [Get]. It cannot (and should not) be accessed
    except through the API in this module. *)

val query_db :
  (Caqti_lwt.connection ->
  ( 'res,
    [< Caqti_error.t > `Connect_failed
    `Connect_rejected
    `Decode_rejected
    `Encode_failed
    `Encode_rejected
    `Post_connect
    `Request_failed
    `Request_rejected
    `Response_failed
    `Response_rejected ] )
  result
  Lwt.t) ->
  Opium_kernel.Rock.Request.t ->
  ('res, string) Lwt_result.t

(** {{1} API for database migrations } *)

module Migration : sig
  (** Interface for executing database migrations *)

  type 'a migration_error =
    [< Caqti_error.t > `Connect_failed `Connect_rejected `Post_connect ] as 'a

  type 'a migration_operation =
    Caqti_lwt.connection -> unit -> (unit, 'a migration_error) result Lwt.t

  type 'a migration_step = string * 'a migration_operation

  type 'a migration = string * 'a migration_step list

  val execute : _ migration list -> (unit, string) result Lwt.t
  (** [execute steps] is [Ok ()] if all the migration tasks in [steps] can be
      executed or [Error err] where [err] explains the reason for failure. *)
end
