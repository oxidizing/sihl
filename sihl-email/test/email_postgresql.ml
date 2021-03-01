let services =
  [ Sihl.Database.Migration.PostgreSql.register ()
  ; Sihl_email.Template.PostgreSql.register ()
  ; Sihl_email.Smtp.register ()
  ]
;;

module Test = Email.Make (Sihl_email.Smtp) (Sihl_email.Template.PostgreSql)

let () =
  let open Lwt.Syntax in
  Unix.putenv "DATABASE_URL" "postgres://admin:password@127.0.0.1:5432/dev";
  Unix.putenv "SIHL_ENV" "test";
  Logs.set_level (Sihl.Log.get_log_level ());
  Logs.set_reporter (Sihl.Log.cli_reporter ());
  Lwt_main.run
    (let* _ = Sihl.Container.start_services services in
     let* () = Sihl.Database.Migration.PostgreSql.run_all () in
     Alcotest_lwt.run "postgresql" Test.suite)
;;
