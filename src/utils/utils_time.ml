open Base

type duration =
  | OneSecond
  | OneMinute
  | TenMinutes
  | OneHour
  | OneDay
  | OneWeek
  | OneMonth
  | OneYear
[@@deriving yojson, show, eq]

let duration_to_span duration =
  let duration_s =
    match duration with
    | OneSecond -> 1.
    | OneMinute -> 60.
    | TenMinutes -> 60. *. 10.
    | OneHour -> 60. *. 60.
    | OneDay -> 60. *. 60. *. 24.
    | OneWeek -> 60. *. 60. *. 24. *. 7.
    | OneMonth -> 60. *. 60. *. 24. *. 30.
    | OneYear -> 60. *. 60. *. 24. *. 365.
  in
  Option.value_exn (Ptime.of_float_s duration_s) |> Ptime.to_span

let ptime_to_yojson ptime = `String (Ptime.to_rfc3339 ptime)

let ptime_of_yojson yojson =
  match
    yojson |> Yojson.Safe.to_string |> Ptime.of_rfc3339
    |> Ptime.rfc3339_error_to_msg
  with
  | Ok (ptime, _, _) -> Ok ptime
  | Error (`Msg msg) -> Error msg
