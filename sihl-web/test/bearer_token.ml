open Lwt.Syntax
open Alcotest_lwt

let apply_middlewares handler =
  let token = Sihl_web.Bearer_token.middleware in
  handler |> Rock.Middleware.apply token
;;

let find_bearer_token _ () =
  let token_value = "tokenvalue123" in
  let token_header = Format.sprintf "Bearer %s" token_value in
  let req =
    Opium.Request.get "/some/path/login"
    |> Opium.Request.add_header ("authorization", token_header)
  in
  let handler req =
    let token = Sihl_web.Bearer_token.find req in
    Alcotest.(check string "has token" token_value token);
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let wrapped_handler = apply_middlewares handler in
  let* _ = wrapped_handler req in
  Lwt.return ()
;;

let suite =
  [ "bearer token", [ test_case "find bearer token" `Quick find_bearer_token ] ]
;;

let () =
  Logs.set_level (Sihl_core.Log.get_log_level ());
  Logs.set_reporter (Sihl_core.Log.cli_reporter ());
  Lwt_main.run (Alcotest_lwt.run "bearer token" suite)
;;
