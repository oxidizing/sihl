module Sig = Sig

module Service : Sig.SERVICE = struct
  let rec chars result n =
    if n > 0 then chars (List.cons (Char.chr (Random.int 255)) result) (n - 1) else result
  ;;

  let bytes ~nr = chars [] nr

  let base64 ~nr =
    Base64.encode_string
      ~alphabet:Base64.uri_safe_alphabet
      (bytes ~nr |> List.to_seq |> String.of_seq)
  ;;

  let start ctx =
    Caml.Random.self_init ();
    Lwt.return ctx
  ;;

  let stop _ = Lwt.return ()
  let lifecycle = Core.Container.Lifecycle.create "random" ~start ~stop

  let configure configuration =
    let configuration = Core.Configuration.make configuration in
    Core.Container.Service.create ~configuration lifecycle
  ;;
end
