module Service = Schedule_service

type t = Schedule_core.t

let create = Schedule_core.create

let every_second = Schedule_core.every_second

let every_hour = Schedule_core.every_hour
