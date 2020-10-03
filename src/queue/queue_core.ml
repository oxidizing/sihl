open Base

(** This is the description of a job. A job dispatch is a job description and some
    arguments/input. *)
module Job = struct
  let default_tries = 5
  let default_retry_delay = Utils.Time.OneMinute

  type 'a t =
    { name : string
    ; with_context : Core.Ctx.t -> Core.Ctx.t
    ; input_to_string : 'a -> string option
    ; string_to_input : string option -> ('a, string) Result.t
    ; handle : Core.Ctx.t -> input:'a -> (unit, string) Result.t Lwt.t
    ; failed : Core.Ctx.t -> (unit, string) Result.t Lwt.t
    ; max_tries : int
    ; retry_delay : Utils.Time.duration
    }
  [@@deriving show, fields]

  let create
      ~name
      ?(with_context = fun ctx -> ctx)
      ~input_to_string
      ~string_to_input
      ~handle
      ?failed
      ()
    =
    let failed = failed |> Option.value ~default:(fun _ -> Lwt_result.return ()) in
    { name
    ; with_context
    ; input_to_string
    ; string_to_input
    ; handle
    ; failed
    ; max_tries = default_tries
    ; retry_delay = default_retry_delay
    }
  ;;

  let set_max_tries max_tries job = { job with max_tries }
  let set_retry_delay retry_delay job = { job with retry_delay }
end

(** A workable job can process a job instance that is persisted. We can not store the job
    directly because of the polymorphic type ('a Job.t). *)
module WorkableJob = struct
  type t =
    { name : string
    ; with_context : Core.Ctx.t -> Core.Ctx.t
    ; work : Core.Ctx.t -> input:string option -> (unit, string) Result.t Lwt.t
    ; failed : Core.Ctx.t -> (unit, string) Result.t Lwt.t
    ; max_tries : int
    ; retry_delay : Utils.Time.duration
    }
  [@@deriving show, fields]

  let of_job job =
    let name = Job.name job in
    let with_context = Job.with_context job in
    let work ctx ~input =
      match (Job.string_to_input job) input with
      | Error msg -> Lwt_result.fail msg
      | Ok input -> (Job.handle job) ctx ~input
    in
    let failed = Job.failed job in
    let max_tries = Job.max_tries job in
    let retry_delay = Job.retry_delay job in
    { name; with_context; work; failed; max_tries; retry_delay }
  ;;
end

(** This is the actual job instance that is derived from the job description ['a Job.t]
    and some input. This needs to be serialized and persisted for persistent job queues. *)
module JobInstance = struct
  module Status = struct
    type t =
      | Pending
      | Succeeded
      | Failed
    [@@deriving yojson, show, eq]

    let to_string = function
      | Pending -> "pending"
      | Succeeded -> "succeeded"
      | Failed -> "failed"
    ;;

    let of_string str =
      match str with
      | "pending" -> Ok Pending
      | "succeeded" -> Ok Succeeded
      | "failed" -> Ok Failed
      | _ -> Error (Printf.sprintf "Unexpected job status %s found" str)
    ;;
  end

  type t =
    { id : Data.Id.t
    ; name : string
    ; input : string option
    ; tries : int
    ; next_run_at : Ptime.t
    ; max_tries : int
    ; status : Status.t
    }
  [@@deriving show, eq, fields, make]

  let create ~input ~delay ~now job =
    let input = Job.input_to_string job input in
    let name = Job.name job in
    let next_run_at =
      delay
      |> Option.map ~f:Utils.Time.duration_to_span
      |> Option.bind ~f:(Ptime.add_span now)
      |> Option.value ~default:now
    in
    let max_tries = Job.max_tries job in
    { id = Data.Id.random ()
    ; name
    ; input
    ; tries = 0
    ; next_run_at
    ; max_tries
    ; status = Status.Pending
    }
  ;;

  let is_pending job_instance = Status.equal job_instance.status Status.Pending
  let incr_tries job_instance = { job_instance with tries = job_instance.tries + 1 }

  let update_next_run_at job job_instance =
    let delay = job |> WorkableJob.retry_delay |> Utils.Time.duration_to_span in
    let next_run_at = Option.value_exn (Ptime.add_span job_instance.next_run_at delay) in
    { job_instance with next_run_at }
  ;;

  let set_failed job_instance = { job_instance with status = Status.Failed }
  let set_succeeded job_instance = { job_instance with status = Status.Succeeded }

  let should_run ~job_instance ~now =
    let tries = job_instance.tries in
    let max_tries = job_instance.max_tries in
    let next_run_at = job_instance.next_run_at in
    let has_tries_left = tries < max_tries in
    let is_after_delay = not (Ptime.is_later next_run_at ~than:now) in
    let is_pending = is_pending job_instance in
    is_pending && has_tries_left && is_after_delay
  ;;
end
