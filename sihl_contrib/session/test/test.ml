open Base
open Alcotest_lwt

let ( let* ) = Lwt.bind

let suite =
  [
    ( "sessions",
      [ (* test_case "create session for anonymous http request without cookie"
         *   `Quick Test_session.test_fetch_any_endpoint_creates_anonymous_session; *) ]
    );
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
