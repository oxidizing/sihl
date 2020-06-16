open Base

(* TODO move to Sihl.Core.Id *)
let uuidv4 () =
  Uuidm.v `V4 |> Uuidm.to_string
  [@@ocaml.deprecated "Use Sihl.Id.random() instead."]

let base64 ~bytes =
  let rec rand result n =
    if n > 0 then rand (result ^ Char.to_string (Random.ascii ())) (n - 1)
    else result
  in
  Base64.encode_string @@ rand "" bytes
