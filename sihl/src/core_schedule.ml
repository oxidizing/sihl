type scheduled_time = Every of Core_time.duration [@@deriving eq, show]

type t =
  { label : string
  ; scheduled_time : scheduled_time
  ; fn : unit -> unit Lwt.t [@opaque] [@equal fun _ _ -> true]
  }
[@@deriving eq, show]

type stop_schedule = unit -> unit

let get_function schedule = schedule.fn

let run_in schedule ~now:_ =
  let scheduled_time = schedule.scheduled_time in
  match scheduled_time with
  | Every duration ->
    duration |> Core_time.duration_to_span |> Ptime.Span.to_float_s
;;

let scheduled_function schedule = schedule.fn
let create scheduled_time f label = { label; scheduled_time; fn = f }
let every_second = Every Core_time.OneSecond
let every_hour = Every Core_time.OneHour
let log_src = Logs.Src.create "sihl.service.schedule"

module Logs = (val Logs.src_log log_src : Logs.LOG)

let registered_schedules : t list ref = ref []

let schedule schedule =
  let should_stop = ref false in
  let stop_schedule () = should_stop := true in
  Logs.info (fun m -> m "Schedule %s" schedule.label);
  let scheduled_function = scheduled_function schedule in
  let rec loop () =
    let now = Ptime_clock.now () in
    let duration = run_in schedule ~now in
    Logs.debug (fun m ->
      m "Run schedule %s in %f seconds" schedule.label duration);
    let%lwt () =
      Lwt.catch
        (fun () -> scheduled_function ())
        (fun exn ->
           Logs.err (fun m ->
             m
               "Exception caught while running schedule, this is a bug in your \
                scheduled function. %s"
               (Printexc.to_string exn));
           Lwt.return ())
    in
    let%lwt () = Lwt_unix.sleep duration in
    if !should_stop
    then (
      let () = Logs.debug (fun m -> m "Stop schedule %s" schedule.label) in
      Lwt.return ())
    else loop ()
  in
  loop () |> ignore;
  stop_schedule
;;

let start ctx =
  List.iter (fun s -> schedule s ()) !registered_schedules;
  Lwt.return ctx
;;

let stop _ = Lwt.return ()
let lifecycle = Core_container.create_lifecycle "schedule" ~start ~stop

let register schedules =
  registered_schedules := schedules;
  Core_container.Service.create lifecycle
;;
