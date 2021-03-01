open Lwt.Syntax

let services =
  [ Sihl_core.Schedule.register ()
  ; Sihl_persistence.Database.register ()
  ; Sihl_persistence.Migration.PostgreSql.register ()
  ; Sihl_queue.PostgreSql.register ()
  ]
;;

module Test = Queue.Make (Sihl_queue.PostgreSql)

let () =
  Unix.putenv "DATABASE_URL" "postgres://admin:password@127.0.0.1:5432/dev";
  Logs.set_level (Sihl_core.Log.get_log_level ());
  Logs.set_reporter (Sihl_core.Log.cli_reporter ());
  Lwt_main.run
    (let* _ = Sihl_core.Container.start_services services in
     let* () = Sihl_persistence.Migration.PostgreSql.run_all () in
     Alcotest_lwt.run "postgresql" Test.suite)
;;
