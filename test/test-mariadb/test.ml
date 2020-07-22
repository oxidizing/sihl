open Base
open Alcotest_lwt

let ( let* ) = Lwt.bind

module TestSuite =
  Test_common.Test.Make (Service.Db) (Service.Repo) (Service.Token)
    (Service.Session)
    (Service.User)
    (Service.Storage)
    (Service.PasswordReset)
    (Service.EmailTemplate)

let test_suite =
  [
    TestSuite.token;
    TestSuite.session;
    TestSuite.storage;
    TestSuite.user;
    TestSuite.email;
    TestSuite.password_reset;
  ]

let config =
  Sihl.Config.create ~development:[]
    ~test:[ ("DATABASE_URL", "mariadb://admin:password@127.0.0.1:3306/dev") ]
    ~production:[]

let services : (module Sihl.Core.Container.SERVICE) list =
  [
    (module Service.Log);
    (module Service.Token);
    (module Service.Session);
    (module Service.User);
    (module Service.Storage);
    (module Service.EmailTemplate);
    (module Service.PasswordReset);
  ]

let () =
  Lwt_main.run
    (let* () =
       let ctx = Sihl.Core.Ctx.empty in
       let* () = Service.Test.services ctx ~config ~services in
       Lwt.return ()
     in
     run "mariadb" @@ test_suite)
