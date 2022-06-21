open Command_pure
module Config = Sihl__config.Config

let fn _ =
  let bin_dune = Config.absolute_path "/_opam/bin/dune" in
  Unix.putenv "SIHL_ENV" "test";
  (* TODO setup signal handlers and kill process *)
  let _ =
    Spawn.spawn ~prog:bin_dune ~argv:[ "dune"; "runtest"; "--root=."; "-w" ] ()
  in
  ()
;;

let cov : t =
  { name = "test.cov"
  ; description = "Run tests and display coverage"
  ; usage = "sihl test.cov"
  ; fn
  ; stateful = false
  }
;;

let t : t =
  { name = "test"
  ; description = "Run tests"
  ; usage = "sihl test"
  ; fn
  ; stateful = false
  }
;;
