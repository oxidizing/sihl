type guard = bool * string

let authorize (can, msg) = if can then Ok () else Error msg

let any guards msg =
  let can =
    guards |> List.map authorize |> List.find_opt Result.is_ok |> Option.is_some
  in
  authorize (can, msg)
;;
