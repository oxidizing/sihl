include Session_core
module Sig = Session_sig
module Service = Session_service
module Schedule = Session_schedule

let add_to_ctx session ctx =
  Core.Ctx.add Sig.ctx_session_key (Session_core.key session) ctx

let create = Session_service.create

let set_value = Session_service.set_value

let remove_value = Session_service.remove_value

let get_value = Session_service.get_value

let get_session = Session_service.get_session

let get_all_sessions = Session_service.get_all_sessions

let insert_session = Session_service.insert_session
