module Service = Schedule_service

type t = Schedule_core.t

let create = Schedule_core.create

let register_schedule _ _ = Lwt_result.fail "TODO register_schedule()"
