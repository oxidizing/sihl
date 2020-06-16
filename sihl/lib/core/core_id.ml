type t = Uuidm.t

let pp = Uuidm.pp

let equal = Uuidm.equal

let random () = Uuidm.v `V4

let of_string id_string =
  match id_string |> Uuidm.of_string with
  | Some id -> Ok id
  | None ->
      Error (Printf.sprintf "Invalid id %s provided, expected uuidv4" id_string)

let to_string id = Uuidm.to_string id

let is_valid_str id_string = id_string |> of_string |> Result.is_ok

module Uuidm = Uuidm
