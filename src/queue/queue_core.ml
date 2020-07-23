module Job = struct
  let default_tries = 5

  let default_retry_delay = Utils.Time.OneMinute

  let default_timeout = Utils.Time.TenMinutes

  type 'a t = {
    name : string;
    input_to_string : 'a -> string;
    string_to_input : string -> (string, string) Result.t;
    handle : Core.Ctx.t -> input:'a -> (unit, string) Result.t Lwt.t;
    failed : Core.Ctx.t -> msg:string -> (unit, string) Result.t Lwt.t;
    max_tries : int;
    retry_delay : Utils.Time.duration;
    timeout : Utils.Time.duration;
  }

  let create ~name ~input_to_string ~string_to_input ~handle ~failed =
    {
      name;
      input_to_string;
      string_to_input;
      handle;
      failed;
      max_tries = default_tries;
      retry_delay = default_retry_delay;
      timeout = default_timeout;
    }

  let set_max_tries max_tries job = { job with max_tries }

  let set_retry_delay retry_delay job = { job with retry_delay }

  let set_timeout timeout job = { job with timeout }
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
      | _ -> Error (Printf.sprintf "Invalid job status %s found" str)
  end

  type t = {
    id : Data.Id.t;
    name : string;
    tries : int;
    last_ran_at : Ptime.t;
    status : Status.t;
  }
  [@@deriving show, eq]
end
