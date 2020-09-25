type t = Yojson.Safe.t

let parse str =
  try Ok (str |> Yojson.Safe.from_string)
  with _ -> Error "failed to parse json"

let parse_opt str = try Some (str |> Yojson.Safe.from_string) with _ -> None

let parse_exn str = str |> Yojson.Safe.from_string

let to_string = Yojson.Safe.to_string

module Yojson = Yojson.Safe
