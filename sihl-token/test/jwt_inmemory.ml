open Lwt.Syntax

let services = [ Sihl_facade.Token.register (module Sihl_token.JwtInMemory) ]

let () =
  Logs.set_level (Sihl_core.Log.get_log_level ());
  Logs.set_reporter (Sihl_core.Log.cli_reporter ());
  Lwt_main.run
    (let* _ = Sihl_core.Container.start_services services in
     Alcotest_lwt.run "token jwt in-memory" Token.suite)
;;
