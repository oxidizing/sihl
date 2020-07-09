module Sig = Authn_sig
module Service = Authn_service

let authenticate = Service.authenticate

let create_session_for = Service.create_session_for
