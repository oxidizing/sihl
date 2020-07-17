include Session_core
module Sig = Session_sig
module Service = Session_service
module Schedule = Session_schedule

let add_to_ctx session ctx =
  Core.Ctx.add Sig.ctx_session_key (Session_core.key session) ctx
