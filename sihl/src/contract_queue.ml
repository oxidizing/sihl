type 'a t =
  { name : string
  ; input_to_string : 'a -> string option
  ; string_to_input : string option -> ('a, string) Result.t
  ; handle : 'a -> (unit, string) Result.t Lwt.t
  ; failed : string -> (unit, string) Result.t Lwt.t
  ; max_tries : int
  ; retry_delay : Core_time.duration
  }

let name = "queue"

module type Sig = sig
  (** [dispatch job ?delay input] queues [job] for processing while input
      [input] is the input that the job needs to run. Use [delay] to run the job
      earliest after a certain amount of time. *)
  val dispatch : 'a t -> ?delay:Core_time.duration -> 'a -> unit Lwt.t

  (** [register_jobs jobs] registers jobs that can be dispatched.

      Only registered jobs can be dispatched. Dispatching a job that was not
      registered does nothing. *)
  val register_jobs : 'a t list -> unit Lwt.t

  val register : ?jobs:'a t list -> unit -> Core_container.Service.t

  include Core_container.Service.Sig
end

(* Common *)

let to_sexp { name; max_tries; retry_delay; _ } =
  let open Sexplib0.Sexp_conv in
  let open Sexplib0.Sexp in
  List
    [ List [ Atom "name"; sexp_of_string name ]
    ; List [ Atom "max_tries"; sexp_of_int max_tries ]
    ; List
        [ Atom "retry_delay"
        ; sexp_of_string (Core_time.show_duration retry_delay)
        ]
    ]
;;

let pp fmt t = Sexplib0.Sexp.pp_hum fmt (to_sexp t)
let default_tries = 5
let default_retry_delay = Core_time.OneMinute

let create ~name ~input_to_string ~string_to_input ~handle ?failed () =
  let failed =
    failed |> Option.value ~default:(fun _ -> Lwt_result.return ())
  in
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
