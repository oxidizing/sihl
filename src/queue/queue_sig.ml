module Job = Queue_core.Job
module JobInstance = Queue_core.JobInstance

module type REPO = sig
  include Data.Repo.Sig.REPO

  val enqueue :
    Core.Ctx.t -> job_instance:JobInstance.t -> (unit, string) Result.t Lwt.t

  val find_workable : Core.Ctx.t -> (JobInstance.t list, string) Result.t Lwt.t

  val update :
    Core.Ctx.t -> job_instance:JobInstance.t -> (unit, string) Result.t Lwt.t
end

module type SERVICE = sig
  include Core.Container.SERVICE

  val dispatch :
    Core.Ctx.t -> job:'a Job.t -> ?delay:Utils.Time.duration -> 'a -> unit Lwt.t
  (** Queue a [job] for processing. Use [delay] to run the job after a certain amount of time. *)

  val register_jobs : Core.Ctx.t -> jobs:'a Job.t list -> unit Lwt.t
end
