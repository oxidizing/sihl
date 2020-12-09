open Lwt.Syntax
module QueueRepo = Sihl_queue.Repo.Memory
module QueueService = Sihl_queue.MakePolling (Sihl_core.Schedule) (QueueRepo)
module Queue = Queue.Make (QueueService)

let services = [ QueueService.register () ]

let () =
  Logs.set_level (Sihl_core.Log.get_log_level ());
  Logs.set_reporter (Sihl_core.Log.cli_reporter ());
  Lwt_main.run
    (let* _ = Sihl_core.Container.start_services services in
     Alcotest_lwt.run "queue memory" Queue.suite)
;;
