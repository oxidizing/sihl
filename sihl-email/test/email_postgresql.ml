open Lwt.Syntax

let services_single_impl =
  [ Sihl_facade.Migration.register
      (module Sihl_persistence.Migration.PostgreSql)
  ; Sihl_facade.Email_template.register (module Sihl_email.Template.PostgreSql)
  ]
;;

let services_multi_impl =
  [ Sihl_facade.Email.register ~default:(module Sihl_email.Smtp) () ]
;;

let services =
  List.append services_single_impl @@ List.concat services_multi_impl
;;

let () =
  Unix.putenv "DATABASE_URL" "postgres://admin:password@127.0.0.1:5432/dev";
  Unix.putenv "SIHL_ENV" "test";
  Logs.set_level (Sihl_core.Log.get_log_level ());
  Logs.set_reporter (Sihl_core.Log.cli_reporter ());
  Lwt_main.run
    (let* _ = Sihl_core.Container.start_services services in
     let* () = Sihl_facade.Migration.run_all () in
     Alcotest_lwt.run "email postgresql" Email.suite)
;;
