type t = Uuidm.t

let pp = Uuidm.pp
let equal = Uuidm.equal
let random () = Uuidm.v `V4

let of_string id_string =
  match id_string |> Uuidm.of_string with
  | Some id -> Ok id
  | None ->
    Error
      (Printf.sprintf
         "Invalid id %s provided, can not convert string to uuidv4"
         id_string)
;;

let of_bytes id_bytes =
  let msg =
    Printf.sprintf "Invalid id %s provided, can not convert bytes to uuidv4" id_bytes
  in
  id_bytes |> Uuidm.of_bytes |> Option.to_result ~none:msg
;;

let to_string id = Uuidm.to_string id
let to_bytes id = Uuidm.to_bytes id
let is_valid_str id_string = id_string |> of_string |> Result.is_ok

let t_string =
  let ( let* ) = Result.bind in
  let encode uuid =
    let* uuid = of_string uuid in
    Ok (to_bytes uuid)
  in
  let decode uuid =
    let* uuid = of_bytes uuid in
    Ok (to_string uuid)
  in
  Caqti_type.(custom ~encode ~decode string)
;;

let t =
  let ( let* ) = Result.bind in
  let encode uuid = Ok (to_bytes uuid) in
  let decode uuid =
    let* uuid = of_bytes uuid in
    Ok uuid
  in
  Caqti_type.(custom ~encode ~decode octets)
;;

module Uuidm = Uuidm
