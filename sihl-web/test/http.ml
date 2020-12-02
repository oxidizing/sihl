open Lwt.Syntax
open Alcotest_lwt

let match_first_route _ () =
  let was_called1 = ref false in
  let was_called2 = ref false in
  let handler1 _ =
    was_called1 := true;
    Lwt.return (Sihl_type.Http_response.of_plain_text "ello 1")
  in
  let handler2 _ =
    was_called2 := true;
    Lwt.return (Sihl_type.Http_response.of_plain_text "ello 2")
  in
  let route1 = Sihl_type.Http_route.get "/some/path" handler1 in
  let route2 = Sihl_type.Http_route.get "/**" handler2 in
  let router =
    Sihl_type.Http_route.router ~scope:"/scope" ~middlewares:[] [ route1; route2 ]
  in
  let _ = Sihl_web.Http.register ~routers:[ router ] () in
  let _ = Sihl_web.Http.start () in
  let* _ =
    Cohttp_lwt_unix.Client.get (Uri.of_string "http://localhost:3000/scope/some/path")
  in
  Alcotest.(check bool "was called" true !was_called1);
  Alcotest.(check bool "was not called" false !was_called2);
  Lwt.return ()
;;

let suite = [ "http", [ test_case "match first route" `Quick match_first_route ] ]

let () =
  Logs.set_level (Sihl_core.Log.get_log_level ());
  Logs.set_reporter (Sihl_core.Log.cli_reporter ());
  Lwt_main.run (Alcotest_lwt.run "opium" suite)
;;
