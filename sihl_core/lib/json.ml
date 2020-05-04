type t = Yojson.Safe.t

let parse str =
  try Ok (str |> Yojson.Safe.from_string)
  with _ -> Error "failed to parse json"

let to_string = Yojson.Safe.to_string
