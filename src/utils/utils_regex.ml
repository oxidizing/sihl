open Base

type t = Pcre.regexp

let of_string string = Pcre.regexp string

let test regexp string = Pcre.pmatch ~rex:regexp string

let extract_last regexp text =
  Pcre.extract_opt ~rex:regexp text
  |> Array.to_list |> List.tl |> Option.bind ~f:List.hd |> Option.join

module Internal_ = Pcre
