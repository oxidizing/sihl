let services =
  [ Sihl.Database.register ()
  ; Sihl.Database.Migration.MariaDb.register ()
  ; Sihl_storage.MariaDb.register ()
  ]
;;

module Test = Storage.Make (Sihl_storage.MariaDb)

let () =
  let open Lwt.Syntax in
  Unix.putenv "DATABASE_URL" "mariadb://admin:password@127.0.0.1:3306/dev";
  Logs.set_level (Sihl.Log.get_log_level ());
  Logs.set_reporter (Sihl.Log.cli_reporter ());
  Lwt_main.run
    (let* _ = Sihl.Container.start_services services in
     let* () = Sihl.Database.Migration.MariaDb.run_all () in
     Alcotest_lwt.run "mariadb" Test.suite)
;;
