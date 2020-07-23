module Job = Queue_core.Job

module type SERVICE = sig
  include Core.Container.SERVICE

  val dispatch :
    Core.Ctx.t -> job:'a Job.t -> ?delay:Utils.Time.duration -> 'a -> unit Lwt.t
  (** Queue a [job] for processing. Use [delay] to run the job after a certain amount of time. *)

  val work_queue : Core.Ctx.t -> jobs:'a Job.t list -> unit Lwt.t
  (** Process the queue then exit. [jobs] are the types of jobs the worker will process. *)
end
