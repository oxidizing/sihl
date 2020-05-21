open Base

let uuidv4 () = Uuidm.v `V4 |> Uuidm.to_string

let base64 ~bytes =
  (* TODO move to Sihl initialization *)
  Random.self_init ();
  let rec rand result n =
    if n > 0 then rand (result ^ Char.to_string (Random.ascii ())) (n - 1)
    else result
  in
  Base64.encode_string @@ rand "" bytes
