include Session_core
module Service = Session_service
module Sig = Session_sig
module Schedule = Session_schedule

let add_to_ctx session ctx =
  Core.Ctx.add Sig.ctx_session_key (Session_core.key session) ctx
