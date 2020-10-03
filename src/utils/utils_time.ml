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
;;

let ptime_to_yojson ptime = `String (Ptime.to_rfc3339 ptime)

let ptime_of_yojson yojson =
  match
    yojson |> Yojson.Safe.to_string |> Ptime.of_rfc3339 |> Ptime.rfc3339_error_to_msg
  with
  | Ok (ptime, _, _) -> Ok ptime
  | Error (`Msg msg) -> Error msg
;;

let ptime_of_date_string date =
  let date =
    date
    |> String.split ~on:'-'
    |> List.map ~f:(fun str -> Option.try_with (fun () -> Int.of_string str))
    |> List.map
         ~f:
           (Result.of_option
              ~error:
                "Invalid date string provided, make sure that year, month and date are \
                 ints")
    |> Result.all
  in
  match date with
  | Ok [ year; month; day ] ->
    Ptime.of_date (year, month, day)
    |> Result.of_option ~error:"Invalid date provided, only format 1990-12-01 is accepted"
  | Ok _ -> Error "Invalid date provided, only format 1990-12-01 is accepted"
  | Error msg -> Error msg
;;

let ptime_to_date_string ptime =
  let year, month, day = Ptime.to_date ptime in
  let month =
    if month < 10 then Printf.sprintf "0%d" month else Printf.sprintf "%d" month
  in
  let day = if day < 10 then Printf.sprintf "0%d" day else Printf.sprintf "%d" day in
  Printf.sprintf "%d-%s-%s" year month day
;;
