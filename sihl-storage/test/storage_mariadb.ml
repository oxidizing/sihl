let services =
  [ Sihl.Database.register ()
  ; Sihl.Database.Migration.MariaDb.register []
  ; Sihl_storage.MariaDb.register ()
  ]
;;

module Test = Storage.Make (Sihl_storage.MariaDb)

let () =
  Sihl.Configuration.read_string "DATABASE_URL_TEST_MARIADB"
  |> Option.value ~default:"mariadb://admin:password@127.0.0.1:3306/dev"
  |> Unix.putenv "DATABASE_URL";
  Logs.set_level (Sihl.Log.get_log_level ());
  Logs.set_reporter (Sihl.Log.cli_reporter ());
  Lwt_main.run
    (let%lwt _ = Sihl.Container.start_services services in
     let%lwt () = Sihl.Database.Migration.MariaDb.run_all () in
     Alcotest_lwt.run "mariadb" Test.suite)
;;
