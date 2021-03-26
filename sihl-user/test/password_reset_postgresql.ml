module TokenService = Sihl_token.JwtPostgreSql

module PasswordResetService =
  Sihl_user.Password_reset.MakePostgreSql (TokenService)

let services =
  [ Sihl.Database.Migration.PostgreSql.register ()
  ; TokenService.register ()
  ; Sihl_user.PostgreSql.register ()
  ; PasswordResetService.register ()
  ]
;;

module Test = Password_reset.Make (Sihl_user.PostgreSql) (PasswordResetService)

let () =
  let open Lwt.Syntax in
  Sihl.Configuration.read_string "DATABASE_URL_TEST_POSTGRESQL"
  |> Option.value ~default:"postgres://admin:password@127.0.0.1:5432/dev"
  |> Unix.putenv "DATABASE_URL";
  Logs.set_level (Sihl.Log.get_log_level ());
  Logs.set_reporter (Sihl.Log.cli_reporter ());
  Lwt_main.run
    (let* _ = Sihl.Container.start_services services in
     let* () = Sihl.Database.Migration.PostgreSql.run_all () in
     Alcotest_lwt.run "postgresql" Test.suite)
;;
