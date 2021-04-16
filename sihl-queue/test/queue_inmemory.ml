let services = [ Sihl.Schedule.register []; Sihl_queue.InMemory.register () ]

module Test = Queue.Make (Sihl_queue.InMemory)

let () =
  Logs.set_level (Sihl.Log.get_log_level ());
  Logs.set_reporter (Sihl.Log.cli_reporter ());
  Lwt_main.run
    (let%lwt _ = Sihl.Container.start_services services in
     Alcotest_lwt.run "in-memory" Test.suite)
;;
