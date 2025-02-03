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
  match Ptime.of_float_s duration_s with
  | Some ptime -> Ptime.to_span ptime
  | None -> failwith "Invalid ptime provided"
;;

let date_from_now now duration =
  match duration |> duration_to_span |> Ptime.add_span now with
  | Some expiration_date -> expiration_date
  | None -> failwith "Could not determine date in the future"
;;

let ptime_to_yojson ptime = `String (Ptime.to_rfc3339 ptime)

let ptime_of_yojson yojson =
  match
    yojson
    |> Yojson.Safe.to_string
    |> Ptime.of_rfc3339
    |> Ptime.rfc3339_error_to_msg
  with
  | Ok (ptime, _, _) -> Ok ptime
  | Error (`Msg msg) -> Error msg
;;

let ptime_of_date_string date =
  let date =
    date
    |> String.split_on_char '-'
    |> List.map int_of_string_opt
    |> List.map
         (Option.to_result
            ~none:
              "Invalid date string provided, make sure that year, month and \
               date are ints")
    |> List.fold_left
         (fun result item ->
            match item with
            | Ok item -> Result.map (List.cons item) result
            | Error msg -> Error msg)
         (Ok [])
    |> Result.map List.rev
  in
  match date with
  | Ok [ year; month; day ] ->
    Ptime.of_date (year, month, day)
    |> Option.to_result
         ~none:"Invalid date provided, only format 1990-12-01 is accepted"
  | Ok _ -> Error "Invalid date provided, only format 1990-12-01 is accepted"
  | Error msg -> Error msg
;;

let ptime_to_date_string ptime =
  let year, month, day = Ptime.to_date ptime in
  let month =
    if month < 10 then Printf.sprintf "0%d" month else Printf.sprintf "%d" month
  in
  let day =
    if day < 10 then Printf.sprintf "0%d" day else Printf.sprintf "%d" day
  in
  Printf.sprintf "%d-%s-%s" year month day
;;

module Span = struct
  let seconds n = Ptime.Span.of_int_s n
  let minutes n = Ptime.Span.of_int_s (60 * n)
  let hours n = Ptime.Span.of_int_s (60 * 60 * n)
  let days n = Ptime.Span.of_int_s (24 * 60 * 60 * n)
  let weeks n = Ptime.Span.of_int_s (7 * 24 * 60 * 60 * n)
end
