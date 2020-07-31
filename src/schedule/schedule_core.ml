type scheduled_time = Every of Utils.Time.duration [@@deriving eq, show]

type t = {
  label : string;
  scheduled_time : scheduled_time;
  fn : unit -> unit Lwt.t;
}
[@@deriving fields]

type stop_schedule = unit -> unit

let get_function schedule = schedule.fn

let run_in schedule ~now:_ =
  let scheduled_time = schedule.scheduled_time in
  match scheduled_time with
  | Every duration ->
      duration |> Utils.Time.duration_to_span |> Ptime.Span.to_float_s

let scheduled_function schedule = schedule.fn

let create scheduled_time ~f ~label = { label; scheduled_time; fn = f }

let every_second = Every Utils.Time.OneSecond

let every_hour = Every Utils.Time.OneHour
