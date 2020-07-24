open Alcotest_lwt

let ( let* ) = Lwt.bind

module Queue =
  Test_common.Test.Queue.Make (Service.Db) (Service.Repo) (Service.Queue)

let config = Sihl.Config.create ~development:[] ~test:[] ~production:[]

let test_suite = [ Queue.test_suite ]

let services : (module Sihl.Core.Container.SERVICE) list = []

let () =
  Lwt_main.run
    (let* () = Lwt.return () in
     run "memory" @@ test_suite)
