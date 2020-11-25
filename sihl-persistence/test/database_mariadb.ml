open Lwt.Syntax

let () =
  Unix.putenv "DATABASE_URL" "mariadb://admin:password@127.0.0.1:3306/dev";
  Logs.set_reporter (Sihl_core.Log.default_reporter ());
  Lwt_main.run
    (let* _ = Sihl_core.Container.start_services [ Database.service ] in
     Alcotest_lwt.run "mariadb" Database.suite)
;;