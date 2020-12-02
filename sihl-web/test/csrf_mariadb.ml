open Lwt.Syntax

module Migration =
  Sihl_persistence.Migration.Make (Sihl_persistence.Migration_repo.MariaDb)

module TokenRepo = Sihl_user.Token_repo.MariaDb (Migration)
module SessionRepo = Sihl_user.Session_repo.MakeMariaDb (Migration)
module Token = Sihl_user.Token.Make (TokenRepo)
module Session = Sihl_user.Session.Make (SessionRepo)
module Csrf = Csrf.Make (Token) (Session)

let services =
  [ Sihl_persistence.Database.register ()
  ; Migration.register ()
  ; Token.register ()
  ; Session.register ()
  ]
;;

let () =
  Unix.putenv "DATABASE_URL" "mariadb://admin:password@127.0.0.1:3306/dev";
  Logs.set_level (Sihl_core.Log.get_log_level ());
  Logs.set_reporter (Sihl_core.Log.cli_reporter ());
  Lwt_main.run
    (let* _ = Sihl_core.Container.start_services services in
     let* () = Migration.run_all () in
     Alcotest_lwt.run "mariadb" Csrf.suite)
;;
