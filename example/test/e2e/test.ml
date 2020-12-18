let services =
  [ Sihl_persistence.Database.register ()
  ; Sihl_facade.Migration.register (module Sihl_persistence.Migration.PostgreSql)
  ; Sihl_facade.User.register (module Sihl_user.User.PostgreSql)
  ; Sihl_facade.Session.register (module Sihl_user.Session.PostgreSql)
  ; Sihl_facade.Authn.register (module Sihl_user.Authn)
  ]
;;

let suite = []

let () =
  let open Lwt.Syntax in
  Unix.putenv "DATABASE_URL" "postgres://admin:password@127.0.0.1:5432/dev";
  Logs.set_level (Sihl_core.Log.get_log_level ());
  Logs.set_reporter (Sihl_core.Log.cli_reporter ());
  Lwt_main.run
    (let* _ = Sihl_core.Container.start_services services in
     let* () = Sihl_facade.Migration.run_all () in
     Alcotest_lwt.run "e2e" suite)
;;
