let base64 ~bytes =
  let rec rand result n =
    if n > 0 then rand Base.(result ^ Char.to_string (Random.ascii ())) (n - 1)
    else result
  in
  Base64.encode_string @@ rand "" bytes

let on_init _ =
  Random.self_init ();
  Lwt_result.return ()

let on_start _ = Lwt_result.return ()

let on_stop _ = Lwt_result.return ()
