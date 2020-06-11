type algorithm = Jwto.algorithm = HS256 | HS512 | Unknown

type t = Jwto.t

type payload = (string * string) list

let empty = []

let add_claim ~key ~value payload = Base.List.cons (key, value) payload

let encode algorithm ~secret payload = Jwto.encode algorithm secret payload

let decode ~secret token = Jwto.decode_and_verify secret token

let get_claim ~key token = token |> Jwto.get_payload |> Jwto.get_claim key

let pp = Jwto.pp

let eq = Jwto.eq

module Jwto = Jwto
