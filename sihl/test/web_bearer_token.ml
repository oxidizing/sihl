open Lwt.Syntax
open Alcotest_lwt

let find_bearer_token _ () =
  let token_value = "tokenvalue123" in
  let token_header = Format.sprintf "Bearer %s" token_value in
  let req =
    Opium.Request.get "/some/path/login"
    |> Opium.Request.add_header ("authorization", token_header)
  in
  let handler req =
    let token = Sihl.Web.Bearer_token.find req in
    Alcotest.(check string "has token" token_value token);
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let middleware = Sihl.Web.Middleware.bearer_token () in
  let wrapped_handler = Rock.Middleware.apply middleware handler in
  let* _ = wrapped_handler req in
  Lwt.return ()
;;

let find_bearer_token_with_space _ () =
  let token_value = "tokenvalue123 and after space" in
  let token_header = Format.sprintf "Bearer %s" token_value in
  let req =
    Opium.Request.get "/some/path/login"
    |> Opium.Request.add_header ("authorization", token_header)
  in
  let handler req =
    let token = Sihl.Web.Bearer_token.find req in
    Alcotest.(check string "has token" "tokenvalue123" token);
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let middleware = Sihl.Web.Middleware.bearer_token () in
  let wrapped_handler = Rock.Middleware.apply middleware handler in
  let* _ = wrapped_handler req in
  Lwt.return ()
;;

let unauthorized _ () =
  let req = Opium.Request.get "/some/path/login" in
  let handler _ = Lwt.return @@ Opium.Response.of_plain_text "" in
  let middleware = Sihl.Web.Middleware.bearer_token () in
  let wrapped_handler = Rock.Middleware.apply middleware handler in
  let* resp = wrapped_handler req in
  let status = Opium.Response.status resp |> Opium.Status.to_code in
  Alcotest.(check int "unauthorized 401" 401 status);
  Lwt.return ()
;;

let unauthorized_with_custom_handler _ () =
  let req = Opium.Request.get "/some/path/login" in
  let handler _ = Lwt.return @@ Opium.Response.of_plain_text "" in
  let unauthenticated_handler _ =
    Lwt.return @@ Opium.Response.of_plain_text "custom error"
  in
  let middleware =
    Sihl.Web.Middleware.bearer_token ~unauthenticated_handler ()
  in
  let wrapped_handler = Rock.Middleware.apply middleware handler in
  let* resp = wrapped_handler req in
  let status = Opium.Response.status resp |> Opium.Status.to_code in
  Alcotest.(check int "ok 200" 200 status);
  let* body = Opium.Response.to_plain_text resp in
  Alcotest.(check string "custom error" "custom error" body);
  Lwt.return ()
;;

let suite =
  [ ( "bearer token"
    , [ test_case "find bearer token" `Quick find_bearer_token
      ; test_case
          "find bearer token with space"
          `Quick
          find_bearer_token_with_space
      ; test_case "unauthorized" `Quick unauthorized
      ; test_case
          "unauthorized with custom handler"
          `Quick
          unauthorized_with_custom_handler
      ] )
  ]
;;

let () =
  Logs.set_level (Sihl.Log.get_log_level ());
  Logs.set_reporter (Sihl.Log.cli_reporter ());
  Lwt_main.run (Alcotest_lwt.run "bearer token" suite)
;;
