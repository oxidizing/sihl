open Alcotest_lwt

let remove_trailing_slash _ () =
  let middleware = Sihl.Web.Middleware.trailing_slash () in
  let req = Opium.Request.get "/foo/bar/" in
  let handler req =
    Alcotest.(
      check string "without trailing slash" "/foo/bar" req.Opium.Request.target);
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let%lwt _ = Rock.Middleware.apply middleware handler req in
  let req = Opium.Request.get "/foo/bar///" in
  let handler req =
    Alcotest.(
      check string "without trailing slash" "/foo/bar" req.Opium.Request.target);
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let%lwt _ = Rock.Middleware.apply middleware handler req in
  let req = Opium.Request.get "/foo/bar/?some=query&other=query" in
  let handler req =
    Alcotest.(
      check
        string
        "without trailing slash"
        "/foo/bar?some=query&other=query"
        req.Opium.Request.target);
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let%lwt _ = Rock.Middleware.apply middleware handler req in
  Lwt.return ()
;;

let suite =
  [ ( "trailing slash"
    , [ test_case "remove trailing slash" `Quick remove_trailing_slash ] )
  ]
;;

let () =
  Logs.set_level (Sihl.Log.get_log_level ());
  Logs.set_reporter (Sihl.Log.cli_reporter ());
  Lwt_main.run (Alcotest_lwt.run "trailing slash" suite)
;;
