open Lwt.Syntax
open Alcotest_lwt
module Token = Test_case.Token.Make (Service.Token)
module Session = Test_case.Session.Make (Service.Session)
module Storage = Test_case.Storage.Make (Service.Storage)
module User = Test_case.User.Make (Service.User)
module Email = Test_case.Email.Make (Service.EmailTemplate)
module Database = Test_case.Database

module PasswordReset =
  Test_case.Password_reset.Make (Service.User) (Service.PasswordReset)

module Queue = Test_case.Queue.Make (Service.Queue)
module Csrf = Test_case.Csrf.Make (Service.Token) (Service.Session)

let test_suite =
  [ Database.test_suite
  ; Token.test_suite
  ; Session.test_suite
  ; Storage.test_suite
  ; User.test_suite
  ; Email.test_suite
  ; PasswordReset.test_suite
  ; Csrf.test_suite (* Put queue tests last because of slowness *)
  ; Queue.test_suite
  ]
;;

let services =
  [ Service.Database.register ()
  ; Service.Session.register ()
  ; Service.Token.register ()
  ; Service.User.register ()
  ; Service.Storage.register ()
  ; Service.EmailTemplate.register ()
  ; Service.PasswordReset.register ()
  ; Service.Queue.register ()
  ]
;;

let () =
  Unix.putenv "DATABASE_URL" "mariadb://admin:password@127.0.0.1:3306/dev";
  Logs.set_reporter (Sihl.Log.default_reporter ());
  Lwt_main.run
    (let* _ = Sihl.Container.start_services services in
     let* () = Service.Migration.run_all () in
     run "mariadb" @@ test_suite)
;;
