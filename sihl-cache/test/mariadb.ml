open Lwt.Syntax

let services =
  [ Sihl_persistence.Database.register ()
  ; Sihl_facade.Migration.register (module Sihl_persistence.Migration.MariaDb)
  ; Sihl_cache.MariaDb.register ()
  ]
;;

module Test = Cache.Make (Sihl_cache.MariaDb)

let () =
  Unix.putenv "DATABASE_URL" "mariadb://admin:password@127.0.0.1:3306/dev";
  Logs.set_level (Sihl_core.Log.get_log_level ());
  Logs.set_reporter (Sihl_core.Log.cli_reporter ());
  Lwt_main.run
    (let* _ = Sihl_core.Container.start_services services in
     let* () = Sihl_facade.Migration.run_all () in
     Alcotest_lwt.run "cache service mariadb" Test.suite)
;;