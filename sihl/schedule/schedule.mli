(** Schedules are functions that need to run periodically, similarly to cron jobs. Use this for instance to run clean up jobs.

*)

module Service = Schedule_service

type t = Schedule_core.t

val create :
  Schedule_core.scheduled_time -> f:(unit -> unit Lwt.t) -> label:string -> t

val every_second : Schedule_core.scheduled_time

val every_hour : Schedule_core.scheduled_time
