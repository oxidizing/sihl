open Lwt.Syntax
module Database = Test_case.Database
module Session = Test_case.Session.Make (Service.Session)
module User = Test_case.User.Make (Service.User)
module Email = Test_case.Email.Make (Service.EmailTemplate)

let test_suite =
  [ Database.test_suite; Session.test_suite; User.test_suite; Email.test_suite ]
;;

let services =
  [ Service.Database.register ()
  ; Service.Session.register ()
  ; Service.User.register ()
  ; Service.EmailTemplate.register ()
  ]
;;

let () =
  Unix.putenv "DATABASE_URL" "postgres://admin:password@127.0.0.1:5432/dev";
  Logs.set_reporter (Sihl.Log.default_reporter ());
  Lwt_main.run
    (let* _ = Sihl.Container.start_services services in
     let* () = Service.Migration.run_all () in
     Alcotest_lwt.run "postgresql" @@ test_suite)
;;
