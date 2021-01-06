type 'a t =
  { name : string
  ; input_to_string : 'a -> string option
  ; string_to_input : string option -> ('a, string) Result.t
  ; handle : 'a -> (unit, string) Result.t Lwt.t
  ; failed : string -> (unit, string) Result.t Lwt.t
  ; max_tries : int
  ; retry_delay : Sihl_core.Time.duration
  }

let name = "queue"

module type Sig = sig
  include Sihl_core.Container.Service.Sig

  (** [dispatch job ?delay input] queues [job] for processing while input
      [input] is the input that the job needs to run. Use [delay] to run the job
      earliest after a certain amount of time. *)
  val dispatch : 'a t -> ?delay:Sihl_core.Time.duration -> 'a -> unit Lwt.t

  (** [register_jobs jobs] registers jobs that can be dispatched.

      Only registered jobs can be dispatched. Dispatching a job that was not
      registered does nothing. *)
  val register_jobs : 'a t list -> unit Lwt.t

  val register : ?jobs:'a t list -> unit -> Sihl_core.Container.Service.t
end
