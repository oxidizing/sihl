(* A workable job can process a job instance that is persisted. We can not store the job
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
  let name = Sihl_contract.Queue.Job.name job in
  let work ~input =
    match (Sihl_contract.Queue.Job.string_to_input job) input with
    | Error msg -> Lwt_result.fail msg
    | Ok input -> (Sihl_contract.Queue.Job.handle job) ~input
  in
  let failed = Sihl_contract.Queue.Job.failed job in
  let max_tries = Sihl_contract.Queue.Job.max_tries job in
  let retry_delay = Sihl_contract.Queue.Job.retry_delay job in
  { name; work; failed; max_tries; retry_delay }
;;
