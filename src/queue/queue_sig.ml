module Job = Queue_core.Job
module JobInstance = Queue_core.JobInstance

module type REPO = sig
  include Data.Repo.Sig.REPO

  val enqueue :
    Data.Db.connection ->
    job_instance:JobInstance.t ->
    (unit, string) Result.t Lwt.t

  val find_pending :
    Data.Db.connection -> (JobInstance.t list, string) Result.t Lwt.t

  val update :
    Data.Db.connection ->
    job_instance:JobInstance.t ->
    (unit, string) Result.t Lwt.t
end

module type SERVICE = sig
  include Core.Container.SERVICE

  val dispatch :
    Core.Ctx.t -> job:'a Job.t -> ?delay:Utils.Time.duration -> 'a -> unit Lwt.t
  (** Queue a [job] for processing. Use [delay] to run the job after a certain amount of time. *)
end
