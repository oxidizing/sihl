(* A workable job can process a job instance that is persisted. We can not store
   the job directly because of the polymorphic type ('a Job.t). *)
type t =
  { name : string
  ; work : string option -> (unit, string) Result.t Lwt.t
  ; failed : string -> (unit, string) Result.t Lwt.t
  ; max_tries : int
  ; retry_delay : Sihl.Time.duration
  }

let of_job job =
  let open Sihl.Contract.Queue in
  let name = job.name in
  let work input =
    match job.string_to_input input with
    | Error msg -> Lwt_result.fail msg
    | Ok input -> job.handle input
  in
  let failed = job.failed in
  let max_tries = job.max_tries in
  let retry_delay = job.retry_delay in
  { name; work; failed; max_tries; retry_delay }
;;
