module Test = Database_migration.Make (Sihl.Database.Migration.MariaDb)

let () =
  Sihl.Configuration.read_string "DATABASE_URL_TEST_MARIADB"
  |> Option.value ~default:"mariadb://admin:password@127.0.0.1:3306/dev"
  |> Unix.putenv "DATABASE_URL";
  Logs.set_level (Sihl.Log.get_log_level ());
  Logs.set_reporter (Sihl.Log.cli_reporter ());
  Lwt_main.run
    (let%lwt _ =
       Sihl.Container.start_services
         [ Sihl.Database.register ()
         ; Sihl.Database.Migration.MariaDb.register ()
         ]
     in
     Alcotest_lwt.run "mariadb" Test.suite)
;;
