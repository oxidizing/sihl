module Core = Message_core
include Message_core.Message

type t = Message_core.Message.t

let set = Message_service.set

let get = Message_service.get

let rotate = Message_service.rotate
