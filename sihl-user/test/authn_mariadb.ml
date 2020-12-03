open Lwt.Syntax

module Migration =
  Sihl_persistence.Migration.Make (Sihl_persistence.Migration_repo.MariaDb)

module SessionRepo = Sihl_user.Session_repo.MakeMariaDb (Migration)
module SessionService = Sihl_user.Session.Make (SessionRepo)
module UserRepo = Sihl_user.User_repo.MakeMariaDb (Migration)
module UserService = Sihl_user.User.Make (UserRepo)
module AuthnService = Sihl_user.Authn.Make (SessionService) (UserService)
module Authn = Authn.Make (SessionService) (UserService) (AuthnService)

let services =
  [ Sihl_persistence.Database.register ()
  ; Migration.register ()
  ; UserService.register ()
  ; SessionService.register ()
  ; AuthnService.register ()
  ]
;;

let () =
  Unix.putenv "DATABASE_URL" "mariadb://admin:password@127.0.0.1:3306/dev";
  Logs.set_level (Sihl_core.Log.get_log_level ());
  Logs.set_reporter (Sihl_core.Log.cli_reporter ());
  Lwt_main.run
    (let* _ = Sihl_core.Container.start_services services in
     let* () = Migration.run_all () in
     Alcotest_lwt.run "authn mariadb" Authn.suite)
;;
