open Base
open Alcotest_lwt
open Lwt.Syntax
module Queue = Test_common.Test.Queue.Make (Service.Repo) (Service.Queue)

let config = Sihl.Config.create ~development:[] ~test:[] ~production:[]

let test_suite ctx = [ Queue.test_suite ctx Fn.id ]

let services : (module Sihl.Core.Container.SERVICE) list =
  [ (module Service.Log); (module Service.Queue) ]

let () =
  Lwt_main.run
    (let* _, ctx = Sihl.Core.Container.start_services services in
     run "memory" @@ test_suite ctx)
