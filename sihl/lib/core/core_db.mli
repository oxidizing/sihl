(** {{1} Type aliases for clearer documentation and explication} *)

type caqti_conn_pool = (Caqti_lwt.connection, Caqti_error.t) Caqti_lwt.Pool.t

type ('res, 'err) query =
  Caqti_lwt.connection -> ('res, ([< Caqti_error.t ] as 'err)) result Lwt.t

type 'a db_result = ('a, Caqti_error.t) Lwt_result.t

type connection = (module Caqti_lwt.CONNECTION)

(** {{1} API for the Opium app database middleware }*)

val clean : (connection -> unit db_result) list -> (unit, string) Lwt_result.t

type db_connection = (module Caqti_lwt.CONNECTION)

val key : db_connection Opium.Hmap.key

val request_with_connection : Opium.Std.Request.t -> Opium.Std.Request.t Lwt.t

val query_db_with_trx :
  Opium_kernel.Rock.Request.t ->
  (connection -> 'a db_result) ->
  ('a, string) result Lwt.t

val query_db_with_trx_exn :
  Opium_kernel.Rock.Request.t -> (connection -> 'a db_result) -> 'a Lwt.t

val query_db_connection :
  connection -> (connection -> 'a db_result) -> ('a, string) result Lwt.t

val query_db :
  Opium_kernel.Rock.Request.t ->
  (connection -> 'a db_result) ->
  ('a, string) result Lwt.t

val query_db_exn :
  ?message:string ->
  Opium_kernel.Rock.Request.t ->
  (connection -> 'a db_result) ->
  'a Lwt.t

val connect : unit -> caqti_conn_pool
