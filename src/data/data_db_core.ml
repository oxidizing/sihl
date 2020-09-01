open Base

exception Exception of string

type pool = (Caqti_lwt.connection, Caqti_error.t) Caqti_lwt.Pool.t

let ctx_key_pool : pool Core_ctx.key = Core_ctx.create_key ()

let ctx_add_pool pool ctx = Core_ctx.add ctx_key_pool pool ctx

type connection = (module Caqti_lwt.CONNECTION)

let ctx_key_connection : connection Core_ctx.key = Core_ctx.create_key ()

let middleware_key_connection : connection Opium.Hmap.key =
  Opium.Hmap.Key.create ("connection", fun _ -> sexp_of_string "connection")

let pool_ref : pool option ref = ref None

let remove_pool ctx = Core.Ctx.remove ctx_key_pool ctx

let add_connection connection ctx =
  Core.Ctx.add ctx_key_connection connection ctx
