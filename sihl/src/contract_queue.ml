exception Exception of string

type instance_status =
  | Pending
  | Succeeded
  | Failed
  | Cancelled
[@@deriving show]

type instance =
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
[@@deriving show]

type 'a job =
  { name : string
  ; encode : 'a -> string
  ; decode : string -> ('a, string) Result.t
  ; handle : ?ctx:(string * string) list -> 'a -> (unit, string) Result.t Lwt.t
  ; failed : ?ctx:(string * string) list -> string -> instance -> unit Lwt.t
  ; max_tries : int
  ; retry_delay : Ptime.Span.t
  ; tag : string option
  }
[@@deriving show]

type job' =
  { name : string
  ; handle :
      ?ctx:(string * string) list -> string -> (unit, string) Result.t Lwt.t
  ; failed : ?ctx:(string * string) list -> string -> instance -> unit Lwt.t
  ; max_tries : int
  ; retry_delay : Ptime.Span.t
  }
[@@deriving show]

let hide (job : 'a job) : job' =
  let handle ?ctx input =
    match job.decode input with
    | Ok decoded -> job.handle ?ctx decoded
    | Error msg -> Lwt.return @@ Error msg
  in
  { name = job.name
  ; handle
  ; failed = job.failed
  ; max_tries = job.max_tries
  ; retry_delay = job.retry_delay
  }
;;

let should_run (job_instance : instance) now =
  let tries = job_instance.tries in
  let max_tries = job_instance.max_tries in
  let next_run_at = job_instance.next_run_at in
  let has_tries_left = tries < max_tries in
  let is_after_delay = not (Ptime.is_later next_run_at ~than:now) in
  let is_pending =
    match job_instance.status with
    | Pending -> true
    | _ -> false
  in
  is_pending && has_tries_left && is_after_delay
;;

let default_tries = 5
let default_retry_delay = Core_time.Span.minutes 1

let default_error_handler ?(ctx = []) msg (instance : instance) =
  let ctx =
    Format.asprintf " (ctx: %s)" ([%show: (string * string) list] ctx)
  in
  Lwt.return
  @@ Logs.err (fun m ->
    m
      "%s Job with id '%s' and name '%s' failed for input '%s': %s"
      ctx
      instance.id
      instance.name
      instance.input
      msg)
;;

let create_job
  handle
  ?(max_tries = default_tries)
  ?(retry_delay = default_retry_delay)
  ?(failed = default_error_handler)
  ?tag
  encode
  decode
  name
  =
  { name; handle; failed; max_tries; retry_delay; encode; decode; tag }
;;

(* Service signature *)

let name = "queue"

module type Sig = sig
  (** [router ?back scope] returns a router that can be passed to the web server
      to serve the job queue dashboard.

      [back] is an optional URL which renders a back button on the dashboard.
      Use this to provide your admin user a way to easily exit the dashboard. By
      default, no URL is provided and no back button is shown.

      [scope] is the URL path under which the dashboard can be accessed. It is
      common to have some admin UI under [/admin], the job queue dashboard could
      be available under [/admin/queue].

      You can use HTMX by setting [HTMX_SCRIPT_URL] to the URL of the HTMX
      JavaScript file that is then embedded into the dashboard using the
      <script> tag in the page body. HTMX is used to add dynamic features such
      as auto-refresh. The dashboard is perfectly usable without it. By default,
      HTMX is not used. *)
  val router
    :  ?back:string
    -> ?theme:[ `Custom of string | `Light | `Dark ]
    -> string
    -> Web.router

  (** [dispatch ?ctx ?delay input job] queues [job] for later processing and
      returns [unit Lwt.t] once the job has been queued.

      An optional [callback] function that will be called after the job has been
      enqueued.

      An optional [delay] determines the amount of time from now (when dispatch
      is called) up until the job can be run. If no delay is specified, the job
      is processed as soon as possible.

      [input] is the input of the [handle] function which is used for job
      processing. *)
  val dispatch
    :  ?callback:(instance -> unit Lwt.t)
    -> ?ctx:(string * string) list
    -> ?delay:Ptime.span
    -> 'a
    -> 'a job
    -> unit Lwt.t

  (** [dispatch_all ?ctx ?delay inputs jobs] queues all [jobs] for later
      processing and returns [unit Lwt.t] once all the jobs has been queued. The
      jobs are put onto the queue in reverse order. The first job in the list of
      [jobs] is put onto the queue last, which means it gets processed first.

      If the queue backend supports transactions, [dispatch_all] guarantees that
      either none or all jobs are queued.

      An optional [callback] function that will be called after the jobs have been
      enqueued.

      An optional [delay] determines the amount of time from now (when dispatch
      is called) up until the jobs can be run. If no delay is specified, the
      jobs are processed as soon as possible.

      [inputs] is the input of the [handle] function. It is a list of ['a], one
      for each ['a job] instance. *)
  val dispatch_all
    :  ?callback:(instance -> unit Lwt.t)
    -> ?ctx:(string * string) list
    -> ?delay:Ptime.span
    -> 'a list
    -> 'a job
    -> unit Lwt.t

  (** [search ?ctx ?sort ?filter ?limit ?offset ()] returns a list of job
      instances that match the search parameters.

      The [filter] has exactly match or be part of the search tag of the job
      instance.

      A tuple is returned, where the second value describes the total number of
      rows found, ignoring [limit]. This is useful to implement pagination. *)
  val search
    :  ?ctx:(string * string) list
    -> ?sort:[ `Desc | `Asc ]
    -> ?filter:string
    -> ?limit:int
    -> ?offset:int
    -> unit
    -> (instance list * int) Lwt.t

  (** [register_jobs jobs] registers jobs that can be dispatched later on.

      Only registered jobs can be dispatched. Dispatching a job that was not
      registered does nothing. *)
  val register_jobs : job' list -> unit Lwt.t

  val register : ?jobs:job' list -> unit -> Core_container.Service.t

  include Core_container.Service.Sig
end
