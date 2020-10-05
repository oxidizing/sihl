type t = Re.Pcre.regexp

let of_string string = Re.Pcre.regexp string
let test regexp string = Re.Pcre.pmatch ~rex:regexp string

let extract_last regexp text =
  let ( let* ) = Option.bind in
  let extracts = Array.to_list (Re.Pcre.extract ~rex:regexp text) in
  let* extracts =
    try Some (List.tl extracts) with
    | _ -> None
  in
  try Some (List.hd extracts) with
  | _ -> None
;;

module Re = Re
