open Lwt.Syntax

module Migration =
  Sihl_persistence.Migration.Make (Sihl_persistence.Migration_repo.PostgreSql)

module UserRepo = Sihl_user.User_repo.MakePostgreSql (Migration)
module UserService = Sihl_user.User.Make (UserRepo)

let services =
  [ Sihl_persistence.Database.register ()
  ; Migration.register ()
  ; UserService.register ()
  ; Sihl_facade.Session.register (module Sihl_user.Session.PostgreSql)
  ; Sihl_facade.Authn.register (module Sihl_user.Authn)
  ]
;;

let () =
  Unix.putenv "DATABASE_URL" "postgres://admin:password@127.0.0.1:5432/dev";
  Logs.set_level (Sihl_core.Log.get_log_level ());
  Logs.set_reporter (Sihl_core.Log.cli_reporter ());
  Lwt_main.run
    (let* _ = Sihl_core.Container.start_services services in
     let* () = Migration.run_all () in
     Alcotest_lwt.run "authn postgresql" Authn.suite)
;;
