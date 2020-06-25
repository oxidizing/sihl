type pool = (Caqti_lwt.connection, Caqti_error.t) Caqti_lwt.Pool.t

val ctx_add_pool : pool -> Core_ctx.t -> Core_ctx.t

type ('res, 'err) query =
  Caqti_lwt.connection -> ('res, ([< Caqti_error.t ] as 'err)) result Lwt.t

type 'a db_result = ('a, Caqti_error.t) Lwt_result.t

type 'a result = ('a, string) Lwt_result.t

type connection = (module Caqti_lwt.CONNECTION)

type db_connection = (module Caqti_lwt.CONNECTION)

val key : db_connection Opium.Hmap.key

val request_with_connection : Opium.Std.Request.t -> Opium.Std.Request.t Lwt.t

val query_db_connection :
  connection -> (connection -> 'a db_result) -> ('a, string) Result.t Lwt.t

val query_db :
  Opium_kernel.Rock.Request.t ->
  (connection -> 'a db_result) ->
  ('a, string) Result.t Lwt.t

val query :
  Opium_kernel.Rock.Request.t ->
  (connection -> ('a, string) Result.t Lwt.t) ->
  ('a, string) Result.t Lwt.t

val query_db_exn :
  ?message:string ->
  Opium_kernel.Rock.Request.t ->
  (connection -> 'a db_result) ->
  'a Lwt.t

val connect : unit -> (pool, string) Result.t

val trx :
  Core_ctx.t ->
  (Core_ctx.t -> ('a, string) Result.t Lwt.t) ->
  ('a, string) Result.t Lwt.t
