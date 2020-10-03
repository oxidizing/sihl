open Base
open Alcotest_lwt
open Lwt.Syntax
module Queue = Test_common.Test.Queue.Make (Service.Repo) (Service.Queue)

let test_suite ctx = [ Queue.test_suite ctx Fn.id ]
let services = [ Service.Queue.configure [] [] ]

let () =
  Logs.set_reporter (Sihl.Core.Log.default_reporter ());
  Lwt_main.run
    (let* _, ctx = Sihl.Core.Container.start_services services in
     run "memory" @@ test_suite ctx)
;;
