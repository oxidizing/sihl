let services =
  [ Sihl_core.Schedule.register (); Sihl_queue.InMemory.register () ]
;;

module Test = Queue.Make (Sihl_queue.InMemory)

let () =
  let open Lwt.Syntax in
  Logs.set_level (Sihl_core.Log.get_log_level ());
  Logs.set_reporter (Sihl_core.Log.cli_reporter ());
  Lwt_main.run
    (let* _ = Sihl_core.Container.start_services services in
     Alcotest_lwt.run "in-memory" Test.suite)
;;
