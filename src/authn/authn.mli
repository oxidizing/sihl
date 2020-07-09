module Sig = Authn_sig
module Service = Authn_service

val authenticate : Core.Ctx.t -> (User.t option, string) Result.t Lwt.t

val create_session_for : Core.Ctx.t -> User.t -> (unit, string) Result.t Lwt.t
