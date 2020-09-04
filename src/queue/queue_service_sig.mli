module Job = Queue_core.Job
module JobInstance = Queue_core.JobInstance

module type REPO = sig
  include Data.Repo.Service.Sig.REPO

  val enqueue : Core.Ctx.t -> job_instance:JobInstance.t -> unit Lwt.t

  val find_workable : Core.Ctx.t -> JobInstance.t list Lwt.t

  val update : Core.Ctx.t -> job_instance:JobInstance.t -> unit Lwt.t
end

module type SERVICE = sig
  include Core.Container.SERVICE

  val dispatch :
    Core.Ctx.t -> job:'a Job.t -> ?delay:Utils.Time.duration -> 'a -> unit Lwt.t
  (** Queue a [job] for processing. Use [delay] to run the initially job after a certain amount of time. *)

  val register_jobs : Core.Ctx.t -> jobs:'a Job.t list -> unit Lwt.t
  (** Register jobs that can be dispatched.

    Only registered jobs can be dispatched. Dispatching a job that was not registered does nothing. *)
end
