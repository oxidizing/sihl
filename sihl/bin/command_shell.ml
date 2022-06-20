let fn _ =
  let bin_dune = Sihl.Config.absolute_path "/_opam/bin/dune" in
  let _ = Spawn.spawn ~prog:bin_dune ~argv:[ "dune"; "utop" ] () in
  ()
;;

let t : Sihl.Command.t =
  { name = "shell"
  ; description = "Open an interactive shell"
  ; usage = "sihl shell"
  ; fn
  }
;;
