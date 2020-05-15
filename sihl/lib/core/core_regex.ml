open Base

type t = Pcre.regexp

let regexp = Pcre.regexp

let extract_last ~rex text =
  Pcre.extract ~rex text |> Array.to_list |> List.tl |> Option.bind ~f:List.hd

module Pcre_ = Pcre
