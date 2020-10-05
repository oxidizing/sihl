module Job = Model.Job
module JobInstance = Model.JobInstance

module type REPO = sig
  include Repository.Sig.REPO

  val enqueue : Core.Ctx.t -> job_instance:JobInstance.t -> unit Lwt.t
  val find_workable : Core.Ctx.t -> JobInstance.t list Lwt.t
  val update : Core.Ctx.t -> job_instance:JobInstance.t -> unit Lwt.t
end

module type SERVICE = sig
  include Core.Container.Service.Sig

  (* TODO [jerben] hide 'a, so jobs of different type can be configured *)
  val configure : Core.Configuration.data -> 'a Job.t list -> Core.Container.Service.t

  (** Queue a [job] for processing. Use [delay] to run the initially job after a certain
      amount of time. *)
  val dispatch
    :  Core.Ctx.t
    -> job:'a Job.t
    -> ?delay:Utils.Time.duration
    -> 'a
    -> unit Lwt.t

  (** Register jobs that can be dispatched.

      Only registered jobs can be dispatched. Dispatching a job that was not registered
      does nothing. *)
  val register_jobs : Core.Ctx.t -> jobs:'a Job.t list -> unit Lwt.t
end
