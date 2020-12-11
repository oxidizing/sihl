module Migration = Sihl_persistence.Migration.MariaDb

let services =
  [ Sihl_persistence.Database.register ()
  ; Sihl_facade.Migration.register (module Migration)
  ; Sihl_facade.User.register (module Sihl_user.User.MariaDb)
  ; Sihl_facade.Session.register (module Sihl_user.Session.MariaDb)
  ; Sihl_facade.Authn.register (module Sihl_user.Authn)
  ]
;;

let () =
  let open Lwt.Syntax in
  Unix.putenv "DATABASE_URL" "mariadb://admin:password@127.0.0.1:3306/dev";
  Logs.set_level (Sihl_core.Log.get_log_level ());
  Logs.set_reporter (Sihl_core.Log.cli_reporter ());
  Lwt_main.run
    (let* _ = Sihl_core.Container.start_services services in
     let* () = Migration.run_all () in
     Alcotest_lwt.run "authn mariadb" Authn.suite)
;;
