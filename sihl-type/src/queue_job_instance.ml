(** This is the actual job instance that is derived from the job description ['a Job.t]
    and some input. This needs to be serialized and persisted for persistent job queues. *)

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
  { id : Database.Id.t
  ; name : string
  ; input : string option
  ; tries : int
  ; next_run_at : Ptime.t
  ; max_tries : int
  ; status : Status.t
  }
[@@deriving show, eq, fields, make]

let create ~input ~delay ~now job =
  let input = Queue_job.input_to_string job input in
  let name = Queue_job.name job in
  let next_run_at =
    match Option.map Sihl_core.Time.duration_to_span delay with
    | Some at -> Option.value (Ptime.add_span now at) ~default:now
    | None -> now
  in
  let max_tries = Queue_job.max_tries job in
  { id = Database.Id.random ()
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
  let delay = job |> Queue_workable_job.retry_delay |> Sihl_core.Time.duration_to_span in
  let next_run_at =
    match Ptime.add_span job_instance.next_run_at delay with
    | Some date -> date
    | None -> failwith "Can not determine next run date of job"
  in
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
