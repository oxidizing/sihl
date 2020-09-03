let rec rand result n =
  if n > 0 then rand Base.(result ^ Char.to_string (Random.ascii ())) (n - 1)
  else result

let base64 ~bytes =
  Base64.encode_string ~alphabet:Base64.uri_safe_alphabet @@ rand "" bytes

let lifecycle =
  Core.Container.Lifecycle.make "random"
    (fun ctx ->
      Random.self_init ();
      Lwt.return ctx)
    (fun _ -> Lwt.return ())
