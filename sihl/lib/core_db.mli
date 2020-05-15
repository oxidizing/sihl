open Opium.Std

(** {{1} Type aliases for clearer documentation and explication} *)

type 'err caqti_conn_pool =
  (Caqti_lwt.connection, ([> Caqti_error.connect ] as 'err)) Caqti_lwt.Pool.t

type ('res, 'err) query =
  Caqti_lwt.connection -> ('res, ([< Caqti_error.t ] as 'err)) result Lwt.t

type 'a db_result = ('a, Caqti_error.t) Lwt_result.t

type connection = (module Caqti_lwt.CONNECTION)

(** {{1} API for the Opium app database middleware }*)

val middleware : unit -> App.builder

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

val query_pool :
  ('a -> ('b, ([< Caqti_error.t ] as 'c)) result Lwt.t) ->
  ('a, 'c) Caqti_lwt.Pool.t ->
  ('b, string) Lwt_result.t

val connect : unit -> 'err caqti_conn_pool
