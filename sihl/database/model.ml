exception Exception of string

type pool = (Caqti_lwt.connection, Caqti_error.t) Caqti_lwt.Pool.t
type connection = (module Caqti_lwt.CONNECTION)

let ctx_key_connection : connection Core.Ctx.key = Core.Ctx.create_key ()
let ctx_key_transaction : connection Core.Ctx.key = Core.Ctx.create_key ()
let find_connection ctx = Core.Ctx.find ctx_key_connection ctx
let add_connection connection ctx = Core.Ctx.add ctx_key_connection connection ctx
let remove_connection ctx = Core.Ctx.remove ctx_key_connection ctx
let find_transaction ctx = Core.Ctx.find ctx_key_transaction ctx
let add_transaction connection ctx = Core.Ctx.add ctx_key_transaction connection ctx
let remove_transaction ctx = Core.Ctx.remove ctx_key_transaction ctx
let pool_ref : pool option ref = ref None
