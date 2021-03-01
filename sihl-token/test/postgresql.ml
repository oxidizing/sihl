let services =
  [ Sihl.Database.register ()
  ; Sihl.Database.Migration.PostgreSql.register ()
  ; Sihl_token.PostgreSql.register ()
  ]
;;

module Test = Token.Make (Sihl_token.PostgreSql)

let () =
  let open Lwt.Syntax in
  Unix.putenv "DATABASE_URL" "postgres://admin:password@127.0.0.1:5432/dev";
  Logs.set_level (Sihl.Log.get_log_level ());
  Logs.set_reporter (Sihl.Log.cli_reporter ());
  Lwt_main.run
    (let* _ = Sihl.Container.start_services services in
     let* () = Sihl.Database.Migration.PostgreSql.run_all () in
     Alcotest_lwt.run "postgresql" Test.suite)
;;
