(** This module provides a job queue. This is typically used for long-running or resource
    intensive tasks. *)

module Core = Sihl_core
module Utils = Sihl_utils
module Job = Model.Job
module JobInstance = Model.JobInstance
module WorkableJob = Model.WorkableJob
module Sig = Sig

val create_job
  :  name:string
  -> ?with_context:(Core.Ctx.t -> Core.Ctx.t)
  -> input_to_string:('a -> string option)
  -> string_to_input:(string option -> ('a, string) Result.t)
  -> handle:(Core.Ctx.t -> input:'a -> (unit, string) Result.t Lwt.t)
  -> ?failed:(Core.Ctx.t -> (unit, string) Result.t Lwt.t)
  -> unit
  -> 'a Model.Job.t

val set_max_tries : int -> 'a Model.Job.t -> 'a Model.Job.t
val set_retry_delay : Utils.Time.duration -> 'a Model.Job.t -> 'a Model.Job.t
