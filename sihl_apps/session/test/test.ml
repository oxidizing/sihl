open Base
open Alcotest_lwt

let ( let* ) = Lwt.bind

let suite =
  [
    ( "session",
      [
        test_case "create session for anonymous http request without cookie"
          `Quick Test_session.test_anonymous_request_returns_cookie;
        test_case "persist session across multiple requests" `Quick
          Test_session.test_requests_persist_session_variables;
        test_case "set session variable" `Quick
          Test_session.test_set_session_variable;
      ] );
  ]

let () =
  let db_name, project =
    match Sys.getenv "DATABASE" with
    | Some "mariadb" -> ("MariaDB", Run_mariadb.project)
    | _ -> ("Postgres", Run_postgresql.project)
  in
  Lwt_main.run
    (let* () = Sihl.Run.Manage.start project in
     let* () = Sihl.Run.Manage.migrate () in
     let* () = run ("session app with " ^ db_name) suite in
     Sihl.Run.Manage.stop ())
