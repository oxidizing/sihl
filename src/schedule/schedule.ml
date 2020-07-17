module Sig = Schedule_sig
module Service = Schedule_service

type t = Schedule_core.t

let create = Schedule_core.create

let register_schedule _ _ =
  Logs.warn (fun m ->
      m "SCHEDULE: Registration of schedules is not implemented");
  Lwt_result.return ()
