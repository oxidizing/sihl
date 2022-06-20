let fn _ =
  let bin_dune = Sihl.Config.absolute_path "/_opam/bin/dune" in
  Unix.putenv "SIHL_ENV" "test";
  let _ =
    Spawn.spawn ~prog:bin_dune ~argv:[ "dune"; "runtest"; "--root=."; "-w" ] ()
  in
  ()
;;

let cov : Sihl.Command.t =
  { name = "test.cov"
  ; description = "Run tests and display coverage"
  ; usage = "sihl test.cov"
  ; fn
  }
;;

let t : Sihl.Command.t =
  { name = "test"; description = "Run tests"; usage = "sihl test"; fn }
;;
