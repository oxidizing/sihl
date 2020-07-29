module Sig = Cmd_sig

module Service : Sig.SERVICE = Cmd_service

include Cmd_core
