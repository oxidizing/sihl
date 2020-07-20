module Service = Data_db_service
module Sig = Data_db_sig

type pool = (Caqti_lwt.connection, Caqti_error.t) Caqti_lwt.Pool.t

val ctx_key_pool : pool Core_ctx.key

val ctx_add_pool : pool -> Core_ctx.t -> Core_ctx.t

type connection = (module Caqti_lwt.CONNECTION)

val ctx_key_connection : connection Core_ctx.key

val middleware_key_connection : connection Opium.Hmap.key

val set_fk_check :
  (module Caqti_lwt.CONNECTION) -> check:bool -> (unit, string) Lwt_result.t
