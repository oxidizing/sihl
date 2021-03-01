open Lwt.Syntax

let services = [ Sihl_token.JwtInMemory.register () ]

module Test = Token.Make (Sihl_token.JwtInMemory)

let () =
  Logs.set_level (Sihl.Log.get_log_level ());
  Logs.set_reporter (Sihl.Log.cli_reporter ());
  Lwt_main.run
    (let* _ = Sihl.Container.start_services services in
     Alcotest_lwt.run "jwt in-memory" Test.suite)
;;
