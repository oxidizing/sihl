open Base
open Lwt.Syntax
open Alcotest_lwt
module Token =
  Test_common.Test.Token.Make (Service.Db) (Service.Repo) (Service.Token)
module Session =
  Test_common.Test.Session.Make (Service.Db) (Service.Repo) (Service.Session)
module Storage =
  Test_common.Test.Storage.Make (Service.Db) (Service.Repo) (Service.Storage)
module User =
  Test_common.Test.User.Make (Service.Db) (Service.Repo) (Service.User)
module Email =
  Test_common.Test.Email.Make (Service.Db) (Service.Repo)
    (Service.EmailTemplate)
module PasswordReset =
  Test_common.Test.PasswordReset.Make (Service.Db) (Service.Repo) (Service.User)
    (Service.PasswordReset)
module Queue = Test_common.Test.Queue.Make (Service.Repo) (Service.Queue)

let test_suite ctx =
  [
    Token.test_suite;
    Session.test_suite;
    Storage.test_suite;
    User.test_suite;
    Email.test_suite;
    PasswordReset.test_suite;
    (* We need to add the DB Pool to the scheduler context *)
    Queue.test_suite ctx Service.Db.add_pool;
  ]

let config =
  Sihl.Config.create ~development:[]
    ~test:[ ("DATABASE_URL", "mariadb://admin:password@127.0.0.1:3306/dev") ]
    ~production:[]

let services : (module Sihl.Core.Container.SERVICE) list =
  [
    (module Service.Db);
    (module Service.Log);
    (module Service.Config);
    (module Service.Token);
    (module Service.Session);
    (module Service.User);
    (module Service.Storage);
    (module Service.EmailTemplate);
    (module Service.PasswordReset);
    (module Service.Queue);
  ]

let () =
  let ctx = Sihl.Core.Ctx.empty in
  Lwt_main.run
    ( Service.Config.register_config config;
      let ctx = Service.Db.add_pool ctx in
      let* _ = Sihl.Core.Container.start_services services in
      let* () = Service.Migration.run_all ctx in
      run "mariadb" @@ test_suite ctx )
