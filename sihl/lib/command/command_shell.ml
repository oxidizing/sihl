module P = Command_pure
module Config = Sihl__config.Config

let fn _ =
  let bin_dune = Config.absolute_path "/_opam/bin/dune" in
  let _ = Spawn.spawn ~prog:bin_dune ~argv:[ "dune"; "utop" ] () in
  ()
;;

let t : P.t =
  { name = "shell"
  ; description = "Open an interactive shell"
  ; usage = "sihl shell"
  ; fn
  }
;;
