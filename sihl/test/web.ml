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
    let token = Sihl.Web.Request.bearer_token req in
    Alcotest.(check (option string) "has token" (Some token_value) token);
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let* _ = handler req in
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
    let token = Sihl.Web.Request.bearer_token req in
    Alcotest.(check (option string) "has token" (Some "tokenvalue123") token);
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let* _ = handler req in
  Lwt.return ()
;;

let suite =
  [ ( "bearer token"
    , [ test_case "find bearer token" `Quick find_bearer_token
      ; test_case
          "find bearer token with space"
          `Quick
          find_bearer_token_with_space
      ] )
  ]
;;

let () =
  Logs.set_level (Sihl.Log.get_log_level ());
  Logs.set_reporter (Sihl.Log.cli_reporter ());
  Lwt_main.run (Alcotest_lwt.run "web" suite)
;;
