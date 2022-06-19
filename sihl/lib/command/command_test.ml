module P = Command_pure
module Config = Sihl__config.Config

let fn _ =
  let bin_dune = Config.absolute_path "/_opam/bin/dune" in
  Unix.putenv "SIHL_ENV" "test";
  let _ =
    Spawn.spawn ~prog:bin_dune ~argv:[ "dune"; "runtest"; "--root=."; "-w" ] ()
  in
  ()
;;

let t : P.t =
  { name = "test"; description = "Runs tests"; usage = "sihl test"; fn }
;;
