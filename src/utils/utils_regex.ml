type t = Pcre.regexp

let of_string string = Pcre.regexp string
let test regexp string = Pcre.pmatch ~rex:regexp string

let extract_last regexp text =
  let ( let* ) = Option.bind in
  let extracts = Array.to_list (Pcre.extract_opt ~rex:regexp text) in
  let* extracts =
    try Some (List.tl extracts) with
    | _ -> None
  in
  try List.hd extracts with
  | _ -> None
;;

module Pcre = Pcre
