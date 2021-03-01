let services =
  [ Sihl_persistence.Migration.PostgreSql.register ()
  ; Sihl_user.PostgreSql.register ()
  ; Sihl_token.JwtPostgreSql.register ()
  ]
;;

module Test = User.Make (Sihl_user.PostgreSql) (Sihl_token.JwtPostgreSql)

let () =
  let open Lwt.Syntax in
  Unix.putenv "DATABASE_URL" "postgres://admin:password@127.0.0.1:5432/dev";
  Logs.set_level (Sihl_core.Log.get_log_level ());
  Logs.set_reporter (Sihl_core.Log.cli_reporter ());
  Lwt_main.run
    (let* _ = Sihl_core.Container.start_services services in
     let* () = Sihl_persistence.Migration.PostgreSql.run_all () in
     Alcotest_lwt.run "mariadb" Test.suite)
;;
