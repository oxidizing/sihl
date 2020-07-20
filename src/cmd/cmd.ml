module Sig = Cmd_sig
module Service = Cmd_service
include Cmd_core

let register_commands = Service.register_commands
