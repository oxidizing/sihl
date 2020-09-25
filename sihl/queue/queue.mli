(** This module provides a job queue. This is typically used for long-running or resource intensive tasks.

*)

module Service = Queue_service
module Job = Queue_core.Job
module JobInstance = Queue_core.JobInstance
module WorkableJob = Queue_core.WorkableJob

val create_job :
  name:string ->
  ?with_context:(Core.Ctx.t -> Core.Ctx.t) ->
  input_to_string:('a -> string option) ->
  string_to_input:(string option -> ('a, string) Result.t) ->
  handle:(Core.Ctx.t -> input:'a -> (unit, string) Result.t Lwt.t) ->
  ?failed:(Core.Ctx.t -> (unit, string) Result.t Lwt.t) ->
  unit ->
  'a Queue_core.Job.t

val set_max_tries : int -> 'a Queue_core.Job.t -> 'a Queue_core.Job.t

val set_retry_delay :
  Utils.Time.duration -> 'a Queue_core.Job.t -> 'a Queue_core.Job.t
