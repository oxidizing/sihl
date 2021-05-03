let services =
  [ Sihl.Database.Migration.MariaDb.register []
  ; Sihl_email.Template.PostgreSql.register ()
  ; Sihl_email.Smtp.register ()
  ]
;;

module Test = Email.Make (Sihl_email.Smtp) (Sihl_email.Template.PostgreSql)

let () =
  Sihl.Configuration.read_string "DATABASE_URL_TEST_POSTGRESQL"
  |> Option.value ~default:"postgres://admin:password@127.0.0.1:5432/dev"
  |> Unix.putenv "DATABASE_URL";
  Unix.putenv "SIHL_ENV" "test";
  Logs.set_level (Sihl.Log.get_log_level ());
  Logs.set_reporter (Sihl.Log.cli_reporter ());
  Lwt_main.run
    (let%lwt _ = Sihl.Container.start_services services in
     let%lwt () = Sihl.Database.Migration.PostgreSql.run_all () in
     Alcotest_lwt.run "postgresql" Test.suite)
;;
