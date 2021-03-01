module TokenService = Sihl_token.JwtMariaDb
module PasswordResetService = Sihl_user.Password_reset.MakeMariaDb (TokenService)

let services =
  [ Sihl.Database.Migration.MariaDb.register ()
  ; TokenService.register ()
  ; Sihl_user.MariaDb.register ()
  ; PasswordResetService.register ()
  ]
;;

module Test = Password_reset.Make (Sihl_user.MariaDb) (PasswordResetService)

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
