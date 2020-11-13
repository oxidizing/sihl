module Repository = Sihl_repository
module Core = Sihl_core
module Utils = Sihl_utils
module Job = Model.Job
module JobInstance = Model.JobInstance

module type REPO = sig
  include Repository.Sig.REPO

  val enqueue : job_instance:JobInstance.t -> unit Lwt.t
  val find_workable : unit -> JobInstance.t list Lwt.t
  val update : job_instance:JobInstance.t -> unit Lwt.t
end

module type SERVICE = sig
  include Core.Container.Service.Sig

  (** Queue a [job] for processing. Use [delay] to run the initially job after a certain
      amount of time. *)
  val dispatch : job:'a Job.t -> ?delay:Utils.Time.duration -> 'a -> unit Lwt.t

  (** Register jobs that can be dispatched.

      Only registered jobs can be dispatched. Dispatching a job that was not registered
      does nothing. *)
  val register_jobs : jobs:'a Job.t list -> unit Lwt.t

  (* TODO [jerben] hide 'a, so jobs of different type can be configured *)
  val register : ?jobs:'a Job.t list -> unit -> Core.Container.Service.t
end
