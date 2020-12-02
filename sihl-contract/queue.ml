open Sihl_type

module type Sig = sig
  include Sihl_core.Container.Service.Sig

  (** Queue a [job] for processing. Use [delay] to run the initially job after a certain
      amount of time. *)
  val dispatch : job:'a Queue_job.t -> ?delay:Sihl_core.Time.duration -> 'a -> unit Lwt.t

  (** Register jobs that can be dispatched.

      Only registered jobs can be dispatched. Dispatching a job that was not registered
      does nothing. *)
  val register_jobs : jobs:'a Queue_job.t list -> unit Lwt.t

  (* TODO [jerben] hide 'a, so jobs of different type can be configured *)
  val register : ?jobs:'a Queue_job.t list -> unit -> Sihl_core.Container.Service.t
end
