open Base
open Alcotest_lwt

let ( let* ) = Lwt.bind

module TestSuite =
  Test_common.Test.Make (Sihl.Data.Db.Service) (Sihl.Data.Repo.Service)
    (Service.Session)
    (Service.User)
    (Service.Storage)
    (Service.EmailTemplate)

let test_suite = [ TestSuite.session; TestSuite.user; TestSuite.email ]

let config =
  Sihl.Config.create ~development:[]
    ~test:[ ("DATABASE_URL", "postgres://admin:password@127.0.0.1:5432/dev") ]
    ~production:[]

let services : (module Sihl.Core.Container.SERVICE) list =
  [
    (module Service.Session);
    (module Service.User);
    (module Service.EmailTemplate);
  ]

let () =
  Lwt_main.run
    (let* () =
       let ctx = Sihl.Core.Ctx.empty in
       let* () = Service.Test.services ctx ~config ~services in
       Lwt.return ()
     in
     run "postgresql" @@ test_suite)
