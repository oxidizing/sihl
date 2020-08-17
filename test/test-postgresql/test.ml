open Base
open Alcotest_lwt

let ( let* ) = Lwt.bind

module Session =
  Test_common.Test.Session.Make (Service.Db) (Service.Repo) (Service.Session)
module User =
  Test_common.Test.User.Make (Service.Db) (Service.Repo) (Service.User)
module Email =
  Test_common.Test.Email.Make (Service.Db) (Service.Repo)
    (Service.EmailTemplate)

let test_suite _ = [ Session.test_suite; User.test_suite; Email.test_suite ]

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
  let ctx = Sihl.Core.Ctx.empty in
  Lwt_main.run
    (let* () =
       Service.Config.register_config ctx config
       |> Lwt.map Result.ok_or_failwith
     in
     let ctx = Service.Db.add_pool ctx in
     let* _ = Sihl.Core.Container.start_services services in
     let* () =
       Service.Migration.run_all ctx |> Lwt.map Base.Result.ok_or_failwith
     in
     run "postgresql" @@ test_suite ctx)
