open Lwt.Syntax
open Alcotest_lwt

(* TODO [jerben] fetch any free port and bind to at, use it in all subsequent tests *)
let match_scoped_route _ () =
  let was_called = ref false in
  let handler _ =
    was_called := true;
    Lwt.return (Sihl_type.Http_response.of_plain_text "ello")
  in
  let route = Sihl_type.Http_route.get "/some/path" handler in
  let router = Sihl_type.Http_route.router ~scope:"/scope" ~middlewares:[] [ route ] in
  let _ = Sihl_web.Http.register ~routers:[ router ] () in
  let _ = Sihl_web.Http.start () in
  let* _ =
    Cohttp_lwt_unix.Client.get (Uri.of_string "http://localhost:3000/scope/some/path")
  in
  Alcotest.(check bool "was called" true !was_called);
  Lwt.return ()
;;

let suite = [ "http", [ test_case "match scoped route" `Quick match_scoped_route ] ]

let () =
  Logs.set_reporter (Sihl_core.Log.default_reporter ());
  Lwt_main.run (Alcotest_lwt.run "opium" suite)
;;
