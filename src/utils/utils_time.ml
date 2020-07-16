let ptime_to_yojson ptime = `String (Ptime.to_rfc3339 ptime)

let ptime_of_yojson yojson =
  match
    yojson |> Yojson.Safe.to_string |> Ptime.of_rfc3339
    |> Ptime.rfc3339_error_to_msg
  with
  | Ok (ptime, _, _) -> Ok ptime
  | Error (`Msg msg) -> Error msg
