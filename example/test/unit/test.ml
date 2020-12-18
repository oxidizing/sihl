open Alcotest_lwt

let suite = []

let () =
  Unix.putenv "SIHL_ENV" "test";
  Lwt_main.run (run "unit tests" suite)
;;
