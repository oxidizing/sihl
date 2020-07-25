open Base
open Alcotest_lwt

let ( let* ) = Lwt.bind

module Queue = Test_common.Test.Queue.Make (Service.Repo) (Service.Queue)

let config = Sihl.Config.create ~development:[] ~test:[] ~production:[]

let test_suite ctx = [ Queue.test_suite ctx ]

let services : (module Sihl.Core.Container.SERVICE) list =
  [ (module Service.Log); (module Service.Queue) ]

let () =
  let ctx = Sihl.Core.Ctx.empty in
  Lwt_main.run
    (let* () =
       let* () =
         Sihl.Core.Container.register_services ctx services
         |> Lwt.map Result.ok_or_failwith
       in
       let* () =
         Sihl.Core.Container.start_services ctx |> Lwt.map Result.ok_or_failwith
       in
       Lwt.return ()
     in
     run "memory" @@ test_suite ctx)
