open Lwt.Syntax

let services =
  [ Sihl_persistence.Migration.MariaDb.register ()
  ; Sihl_token.MariaDb.register ()
  ]
;;

let () =
  Unix.putenv "DATABASE_URL" "mariadb://admin:password@127.0.0.1:3306/dev";
  Logs.set_level (Sihl_core.Log.get_log_level ());
  Logs.set_reporter (Sihl_core.Log.cli_reporter ());
  Lwt_main.run
    (let* _ = Sihl_core.Container.start_services services in
     let* () = Sihl_persistence.Migration.MariaDb.run_all () in
     Alcotest_lwt.run "mariadb csrf" Csrf.suite)
;;
