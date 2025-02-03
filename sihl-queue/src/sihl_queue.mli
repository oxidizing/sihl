(** [instance_status] is the status of the job on the queue. *)
type instance_status = Sihl.Contract.Queue.instance_status =
  | Pending
  | Succeeded
  | Failed
  | Cancelled

(** [instance] is a queued job with a concrete input. *)
type instance = Sihl.Contract.Queue.instance =
  { id : string
  ; name : string
  ; input : string
  ; tries : int
  ; next_run_at : Ptime.t
  ; max_tries : int
  ; status : instance_status
  ; last_error : string option
  ; last_error_at : Ptime.t option
  ; tag : string option
  ; ctx : (string * string) list
  }

(** ['a job] is a job that can be dispatched where ['a] is the type of the
    input. *)
type 'a job = 'a Sihl.Contract.Queue.job =
  { name : string
  ; encode : 'a -> string
  ; decode : string -> ('a, string) Result.t
  ; handle : ?ctx:(string * string) list -> 'a -> (unit, string) Result.t Lwt.t
  ; failed : ?ctx:(string * string) list -> string -> instance -> unit Lwt.t
  ; max_tries : int
  ; retry_delay : Ptime.Span.t
  ; tag : string option
  }

(** [job'] is a helper type that is used to remove the input type from [job].
    Use [job'] to register jobs. *)
type job' = Sihl.Contract.Queue.job' =
  { name : string
  ; handle :
      ?ctx:(string * string) list -> string -> (unit, string) Result.t Lwt.t
  ; failed : ?ctx:(string * string) list -> string -> instance -> unit Lwt.t
  ; max_tries : int
  ; retry_delay : Ptime.Span.t
  }

(** [hide job] returns a [job'] that can be registered with the queue service.
    It hides the input type of the job. A [job'] can be registered but not
    dispatched. *)
val hide : 'a job -> job'

(** [create_job handle ?max_tries ?retry_delay ?failed handle encode decode name]
    returns a job that can be placed on the queue (dispatched) for later
    processing.

    [handle] is the function that is called with the input when processing the
    job. If an exception is raised, the exception is turned into [Error].

    [max_tries] is the maximum times a job can fail. If a job fails [max_tries]
    number of times, the status of the job becomes [Failed]. By default, a job
    can fail [5] times.

    [retry_delay] is the time span between two retries. By default, this value
    is one minute.

    [failed] is the error handler that is called when [handle] returns an error
    or raises an exception. By default, this function does nothing. Use [failed]
    to clean up resources or raise some error in a monitoring system in case a
    job fails.

    [tag] is a string that can be used to search job instances on the queue. It
    does not have to be unique.

    [encode] is called right after dispatching a job. The provided input data is
    encoded as string which is used for persisting the queue.

    [decode] is called before starting to process a job. [decode] turns the
    persisted string into the input data that is passed to the handle function.

    [name] is the name of the job, it has to be unique among all registered
    jobs. *)
val create_job
  :  (?ctx:(string * string) list -> 'a -> (unit, string) result Lwt.t)
  -> ?max_tries:int
  -> ?retry_delay:Ptime.span
  -> ?failed:(?ctx:(string * string) list -> string -> instance -> unit Lwt.t)
  -> ?tag:string
  -> ('a -> string)
  -> (string -> ('a, string) Result.t)
  -> string
  -> 'a job

val pp_job
  :  (Format.formatter -> 'a -> unit)
  -> Format.formatter
  -> 'a job
  -> unit

val pp_job' : Format.formatter -> job' -> unit
val pp_instance : Format.formatter -> instance -> unit

(** [should_run job now] returns true if the queued [job] should run [now],
    false if not. If a queued [job] should run it will be processed by any idle
    worker as soon as possible. *)
val should_run : instance -> Ptime.t -> bool

val log_src : Logs.src

module InMemory : sig
  (** The in-memory queue is not a persistent queue. If the process goes down,
      all jobs are lost. It doesn't support locking and the queue is unbounded,
      use it only for testing! *)
  include Sihl.Contract.Queue.Sig
end

module MariaDb : sig
  (** The MariaDB queue backend supports fully persistent queues and locking. *)
  include Sihl.Contract.Queue.Sig
end

module PostgreSql : sig
  (** The PostgreSQL queue backend supports fully persistent queues and locking.
  *)
  include Sihl.Contract.Queue.Sig
end
