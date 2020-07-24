open Base
open Alcotest_lwt

let ( let* ) = Lwt.bind

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
module Queue =
  Test_common.Test.Queue.Make (Service.Db) (Service.Repo) (Service.Queue)

let test_suite =
  [
    Token.test_suite;
    Session.test_suite;
    Storage.test_suite;
    User.test_suite;
    Email.test_suite;
    PasswordReset.test_suite;
    Queue.test_suite;
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
    (module Service.Queue);
  ]

let () =
  Lwt_main.run
    (let* () =
       let ctx = Sihl.Core.Ctx.empty in
       let* () = Service.Test.services ctx ~config ~services in
       Lwt.return ()
     in
     run "mariadb" @@ test_suite)
