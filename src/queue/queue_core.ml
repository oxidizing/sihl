module Job = struct
  let default_tries = 5

  let default_retry_delay = Utils.Time.OneMinute

  type 'a t = {
    name : string;
    input_to_string : 'a -> string option;
    string_to_input : string option -> ('a, string) Result.t;
    handle : Core.Ctx.t -> input:'a -> (unit, string) Result.t Lwt.t;
    failed : Core.Ctx.t -> (unit, string) Result.t Lwt.t;
    max_tries : int;
    retry_delay : Utils.Time.duration;
  }
  [@@deriving show, fields]

  let create ~name ~input_to_string ~string_to_input ~handle ~failed =
    {
      name;
      input_to_string;
      string_to_input;
      handle;
      failed;
      max_tries = default_tries;
      retry_delay = default_retry_delay;
    }

  let set_max_tries max_tries job = { job with max_tries }

  let set_retry_delay retry_delay job = { job with retry_delay }
end

module JobInstance = struct
  module Status = struct
    type t = Pending | Succeeded | Failed [@@deriving yojson, show, eq]

    let to_string = function
      | Pending -> "pending"
      | Succeeded -> "succeeded"
      | Failed -> "failed"

    let of_string str =
      match str with
      | "pending" -> Ok Pending
      | "succeeded" -> Ok Succeeded
      | "failed" -> Ok Failed
      | _ -> Error (Printf.sprintf "Unexpected job status %s found" str)
  end

  type t = {
    id : Data.Id.t;
    input : string option;
    name : string;
    tries : int;
    start_at : Ptime.t;
    last_ran_at : Ptime.t option;
    status : Status.t;
  }
  [@@deriving show, eq, fields, make]

  let create ~input ~name ~start_at =
    {
      id = Data.Id.random ();
      input;
      name;
      tries = 0;
      start_at;
      last_ran_at = None;
      status = Status.Pending;
    }

  let is_pending job_instance = job_instance.status == Status.Pending

  let incr_tries job_instance =
    { job_instance with tries = job_instance.tries + 1 }

  let set_last_ran_at now job_instance =
    { job_instance with last_ran_at = Some now }

  let set_failed job_instance = { job_instance with status = Status.Failed }

  let set_succeeded job_instance =
    { job_instance with status = Status.Succeeded }

  let should_run ~job ~job_instance ~now =
    let tries = job_instance.tries in
    let max_tries = Job.max_tries job in
    let start_at = job_instance.start_at in
    let retry_delay = Job.retry_delay job |> Utils.Time.duration_to_span in
    let earliest_retry_at =
      if Option.is_some job_instance.last_ran_at then
        Ptime.add_span now retry_delay |> Option.value ~default:now
      else now
    in
    let has_tries_left = tries < max_tries in
    let is_after_delay = not (Ptime.is_later start_at ~than:now) in
    let is_after_retry_delay =
      not (Ptime.is_later earliest_retry_at ~than:now)
    in
    let is_pending = is_pending job_instance in
    is_pending && has_tries_left && is_after_delay && is_after_retry_delay
end
