open Base

type algorithm = Jwto.algorithm = HS256 | HS512 | Unknown

type t = Jwto.t

type payload = (string * string) list

let empty = []

let add_claim ~key ~value payload = Base.List.cons (key, value) payload

let set_expires_in ~now duration payload =
  let span = Utils_time.duration_to_span duration in
  let epoch_s =
    Ptime.add_span now span
    |> Option.map ~f:Ptime.to_float_s
    |> Option.map ~f:Float.to_string
  in
  match epoch_s with
  | Some epoch_s -> add_claim ~key:"exp" ~value:epoch_s payload
  | None -> payload

let encode algorithm ~secret payload = Jwto.encode algorithm secret payload

let decode ~secret token = Jwto.decode_and_verify secret token

let get_claim ~key token = token |> Jwto.get_payload |> Jwto.get_claim key

let is_expired ~now ?(claim = "exp") token =
  token |> get_claim ~key:claim
  |> Option.bind ~f:(fun exp -> Option.try_with (fun () -> Float.of_string exp))
  |> Option.bind ~f:Ptime.of_float_s
  |> Option.map ~f:(fun exp -> Ptime.is_earlier exp ~than:now)
  |> Option.value ~default:false

let pp = Jwto.pp

let eq = Jwto.eq

module Jwto = Jwto
