open Base

module Message = struct
  type t = Error of string | Warning of string | Success of string
  [@@deriving sexp]

  let pp fmt (flash : t) =
    let s =
      match flash with
      | Error msg -> msg
      | Warning msg -> msg
      | Success msg -> msg
    in
    Caml.Format.pp_print_string fmt s

  let equal f1 f2 =
    match (f1, f2) with
    | Success msg1, Success msg2 -> String.equal msg1 msg2
    | Warning msg1, Warning msg2 -> String.equal msg1 msg2
    | Error msg1, Error msg2 -> String.equal msg1 msg2
    | _ -> false
end
