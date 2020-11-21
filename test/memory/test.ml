open Alcotest_lwt
open Lwt.Syntax
module Queue = Test_case.Queue.Make (Service.Queue)

let test_suite = [ Queue.test_suite ]
let services = [ Service.Queue.register () ]

let () =
  Logs.set_reporter (Sihl.Log.default_reporter ());
  Lwt_main.run
    (let* _ = Sihl.Container.start_services services in
     run "memory" @@ test_suite)
;;
