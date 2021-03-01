(* This is the actual job instance that is derived from the job description ['a
   Job.t] and some input. This needs to be serialized and persisted for
   persistent job queues. *)

module Status = struct
  type t =
    | Pending
    | Succeeded
    | Failed

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
  { id : string
  ; name : string
  ; input : string option
  ; tries : int
  ; next_run_at : Ptime.t
  ; max_tries : int
  ; status : Status.t
  }

let sexp_of_t { id; input; name; tries; next_run_at; max_tries; status } =
  let open Sexplib0.Sexp_conv in
  let open Sexplib0.Sexp in
  List
    [ List [ Atom "id"; sexp_of_string id ]
    ; List [ Atom "input"; sexp_of_option sexp_of_string input ]
    ; List [ Atom "name"; sexp_of_string name ]
    ; List [ Atom "tries"; sexp_of_int tries ]
    ; List [ Atom "next_run_at"; sexp_of_string (Ptime.to_rfc3339 next_run_at) ]
    ; List [ Atom "max_tries"; sexp_of_int max_tries ]
    ; List [ Atom "status"; sexp_of_string (Status.to_string status) ]
    ]
;;

let pp fmt t = Sexplib0.Sexp.pp_hum fmt (sexp_of_t t)

let create ~input ~delay ~now job =
  let open Sihl.Contract.Queue in
  let input = job.input_to_string input in
  let name = job.name in
  let next_run_at =
    match Option.map Sihl.Time.duration_to_span delay with
    | Some at -> Option.value (Ptime.add_span now at) ~default:now
    | None -> now
  in
  let max_tries = job.max_tries in
  { id = Uuidm.v `V4 |> Uuidm.to_string
  ; name
  ; input
  ; tries = 0
  ; next_run_at
  ; max_tries
  ; status = Status.Pending
  }
;;

let is_pending job_instance =
  match job_instance.status with
  | Status.Pending -> true
  | _ -> false
;;

let incr_tries job_instance =
  { job_instance with tries = job_instance.tries + 1 }
;;

let update_next_run_at job job_instance =
  let delay = job.Workable_job.retry_delay |> Sihl.Time.duration_to_span in
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
