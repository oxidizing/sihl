module Sig = Utils_random_service_sig

module Make () : Sig.SERVICE = struct
  let rec rand result n =
    if n > 0 then rand Base.(result ^ Char.to_string (Random.ascii ())) (n - 1)
    else result

  let base64 ~bytes =
    Base64.encode_string ~alphabet:Base64.uri_safe_alphabet @@ rand "" bytes

  let start ctx =
    Random.self_init ();
    Lwt.return ctx

  let stop _ = Lwt.return ()

  let lifecycle = Core.Container.Lifecycle.make "random" ~start ~stop
end
