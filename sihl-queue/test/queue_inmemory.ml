open Lwt.Syntax

let services =
  [ Sihl_facade.Schedule.register (module Sihl_core.Schedule)
  ; Sihl_facade.Queue.register (module Sihl_queue.InMemory)
  ]
;;

let suite = Queue.with_implementation (module Sihl_queue.InMemory)

let () =
  Logs.set_level (Sihl_core.Log.get_log_level ());
  Logs.set_reporter (Sihl_core.Log.cli_reporter ());
  Lwt_main.run
    (let* _ = Sihl_core.Container.start_services services in
     Alcotest_lwt.run "queue in-memory" suite)
;;
