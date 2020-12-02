open Lwt.Syntax

module Migration =
  Sihl_persistence.Migration.Make (Sihl_persistence.Migration_repo.MariaDb)

module TokenRepo = Sihl_user.Token_repo.MariaDb (Migration)
module TokenService = Sihl_user.Token.Make (TokenRepo)
module Token = Token.Make (TokenService)

let services =
  [ Sihl_persistence.Database.register ()
  ; Migration.register ()
  ; TokenService.register ()
  ]
;;

let () =
  Unix.putenv "DATABASE_URL" "mariadb://admin:password@127.0.0.1:3306/dev";
  Logs.set_level (Sihl_core.Log.get_log_level ());
  Logs.set_reporter (Sihl_core.Log.cli_reporter ());
  Lwt_main.run
    (let* _ = Sihl_core.Container.start_services services in
     let* () = Migration.run_all () in
     Alcotest_lwt.run "mariadb" Token.suite)
;;
