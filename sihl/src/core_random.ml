let () = Caml.Random.self_init ()

let rec chars result n =
  if n > 0
  then chars (List.cons (Char.chr (Caml.Random.int 255)) result) (n - 1)
  else result
;;

let bytes nr = chars [] nr

let base64 nr =
  Base64.encode_string
    ~alphabet:Base64.uri_safe_alphabet
    (bytes nr |> List.to_seq |> String.of_seq)
;;

let start () = Lwt.return ()
let stop () = Lwt.return ()
let lifecycle = Core_container.create_lifecycle "random" ~start ~stop
let register () = Core_container.Service.create lifecycle
