(** Schedules are functions that need to run periodically, similarly to cron jobs. Use
    this for instance to run clean up jobs. *)

module Service : Sig.SERVICE
module Sig = Sig

type t = Model.t

val create : Model.scheduled_time -> f:(unit -> unit Lwt.t) -> label:string -> t
val every_second : Model.scheduled_time
val every_hour : Model.scheduled_time
