module Service = Message_service
module Sig = Message_sig
module Core = Message_core
include Message_core.Message

type t = Message_core.Message.t
