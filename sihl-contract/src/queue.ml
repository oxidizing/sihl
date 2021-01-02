module Job = struct
  (* This is the description of a job. A job dispatch is a job description and some
     arguments/input. *)
  let default_tries = 5
  let default_retry_delay = Sihl_core.Time.OneMinute

  type 'a t =
    { name : string
    ; input_to_string : 'a -> string option
    ; string_to_input : string option -> ('a, string) Result.t
    ; handle : input:'a -> (unit, string) Result.t Lwt.t
    ; failed : unit -> (unit, string) Result.t Lwt.t
    ; max_tries : int
    ; retry_delay : Sihl_core.Time.duration
    }
  [@@deriving show, fields]

  let create ~name ~input_to_string ~string_to_input ~handle ?failed () =
    let failed = failed |> Option.value ~default:(fun _ -> Lwt_result.return ()) in
    { name
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

(* Signature *)
let name = "sihl.service.queue"

module type Sig = sig
  include Sihl_core.Container.Service.Sig

  (** Queue a [job] for processing. Use [delay] to run the initially job after a certain
      amount of time. *)
  val dispatch : job:'a Job.t -> ?delay:Sihl_core.Time.duration -> 'a -> unit Lwt.t

  (** Register jobs that can be dispatched.

      Only registered jobs can be dispatched. Dispatching a job that was not registered
      does nothing. *)
  val register_jobs : jobs:'a Job.t list -> unit Lwt.t

  (* TODO [jerben] hide 'a, so jobs of different type can be configured *)
  val register : ?jobs:'a Job.t list -> unit -> Sihl_core.Container.Service.t
end
