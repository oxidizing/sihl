open Alcotest_lwt
open Lwt.Syntax

let apply_middlewares handler =
  let token = Sihl_web.Bearer_token.middleware in
  let authentication = Sihl_web.Authentication.token_middleware () in
  let user = Sihl_web.User.token_middleware () in
  handler
  |> Rock.Middleware.apply user
  |> Rock.Middleware.apply authentication
  |> Rock.Middleware.apply token
;;

let bearer_token_fetch_user _ () =
  let* () = Sihl_core.Cleaner.clean_all () in
  let* user =
    Sihl_facade.User.create_user
      ~email:"foo@example.com"
      ~password:"123123"
      ~username:None
  in
  let* token = Sihl_facade.Token.create [ "user_id", user.id ] in
  let token_header = Format.sprintf "Bearer %s" token in
  let req =
    Opium.Request.get "/some/path/login"
    |> Opium.Request.add_header ("authorization", token_header)
  in
  let handler req =
    let user = Sihl_web.User.find req in
    let email = user.email in
    Alcotest.(check string "has same email" "foo@example.com" email);
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let wrapped_handler = apply_middlewares handler in
  let* _ = wrapped_handler req in
  Lwt.return ()
;;

type token = { token : string } [@@deriving yojson]

let bearer_token_login _ () =
  let* () = Sihl_core.Cleaner.clean_all () in
  let* _ =
    Sihl_facade.User.create_user
      ~email:"foo@example.com"
      ~password:"123123"
      ~username:None
  in
  let req = Opium.Request.get "/some/path/login" in
  let handler _ =
    let res = Opium.Response.of_plain_text "" in
    let res =
      Sihl_web.Authentication.login
        ~email:"foo@example.com"
        ~password:"123123"
        res
    in
    Lwt.return res
  in
  let wrapped_handler = apply_middlewares handler in
  let* resp = wrapped_handler req in
  let* json = Opium.Response.to_json_exn resp in
  let { token } = token_of_yojson json |> Result.get_ok in
  let token_header = Format.sprintf "Bearer %s" token in
  let req =
    Opium.Request.get "/some/api/path"
    |> Opium.Request.add_header ("authorization", token_header)
  in
  let handler req =
    let user = Sihl_web.User.find req in
    let email = user.email in
    Alcotest.(check string "has same email" "foo@example.com" email);
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let wrapped_handler = apply_middlewares handler in
  let* _ = wrapped_handler req in
  Lwt.return ()
;;

let bearer_token_logout _ () =
  let* () = Sihl_core.Cleaner.clean_all () in
  let* user =
    Sihl_facade.User.create_user
      ~email:"foo@example.com"
      ~password:"123123"
      ~username:None
  in
  let* token = Sihl_facade.Token.create [ "user_id", user.id ] in
  let token_header = Format.sprintf "Bearer %s" token in
  let req =
    Opium.Request.get "/some/path/login"
    |> Opium.Request.add_header ("authorization", token_header)
  in
  let handler req =
    let user = Sihl_web.User.find req in
    let email = user.email in
    Alcotest.(check string "has same email" "foo@example.com" email);
    let res = Opium.Response.of_plain_text "" |> Sihl_web.User.logout in
    Lwt.return res
  in
  let wrapped_handler = apply_middlewares handler in
  let* _ = wrapped_handler req in
  let handler req =
    let () =
      match Sihl_web.User.find_opt req with
      | None -> ()
      | Some _ -> Alcotest.fail "User should be logged out"
    in
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let wrapped_handler = apply_middlewares handler in
  let* _ = wrapped_handler req in
  Lwt.return ()
;;

let suite =
  [ ( "user"
    , [ test_case "bearer token fetch user" `Quick bearer_token_fetch_user
      ; test_case "bearer token login" `Quick bearer_token_login
      ; test_case "bearer token logout" `Quick bearer_token_logout
      ] )
  ]
;;
