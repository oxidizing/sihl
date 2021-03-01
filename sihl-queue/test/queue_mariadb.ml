let services =
  [ Sihl_core.Schedule.register ()
  ; Sihl_persistence.Database.register ()
  ; Sihl_persistence.Migration.MariaDb.register ()
  ; Sihl_queue.MariaDb.register ()
  ]
;;

module Test = Queue.Make (Sihl_queue.MariaDb)

let () =
  let open Lwt.Syntax in
  Unix.putenv "DATABASE_URL" "mariadb://admin:password@127.0.0.1:3306/dev";
  Logs.set_level (Sihl_core.Log.get_log_level ());
  Logs.set_reporter (Sihl_core.Log.cli_reporter ());
  Lwt_main.run
    (let* _ = Sihl_core.Container.start_services services in
     let* () = Sihl_persistence.Migration.MariaDb.run_all () in
     Alcotest_lwt.run "mariadb" Test.suite)
;;
