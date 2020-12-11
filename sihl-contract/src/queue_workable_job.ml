(** A workable job can process a job instance that is persisted. We can not store the job
    directly because of the polymorphic type ('a Job.t). *)
type t =
  { name : string
  ; work : input:string option -> (unit, string) Result.t Lwt.t
  ; failed : unit -> (unit, string) Result.t Lwt.t
  ; max_tries : int
  ; retry_delay : Sihl_core.Time.duration
  }
[@@deriving show, fields]

let of_job job =
  let name = Queue_job.name job in
  let work ~input =
    match (Queue_job.string_to_input job) input with
    | Error msg -> Lwt_result.fail msg
    | Ok input -> (Queue_job.handle job) ~input
  in
  let failed = Queue_job.failed job in
  let max_tries = Queue_job.max_tries job in
  let retry_delay = Queue_job.retry_delay job in
  { name; work; failed; max_tries; retry_delay }
;;
