open Alcotest_lwt
open Lwt.Syntax

let token_alco = Alcotest.testable Sihl_type.Token.pp Sihl_type.Token.equal

module Make
    (TokenService : Sihl_contract.Token.Sig)
    (SessionService : Sihl_contract.Session.Sig) =
struct
  module Middleware = Sihl_web.Middleware.Csrf.Make (TokenService) (SessionService)
  module SessionMiddleware = Sihl_web.Middleware.Session.Make (SessionService)

  let get_secret tk =
    tk
    |> Base64.decode ~alphabet:Base64.uri_safe_alphabet
    |> Result.get_ok
    |> String.to_seq
    |> List.of_seq
    |> fun tk ->
    Sihl_core.Utils.Encryption.decrypt_with_salt
      ~salted_cipher:tk
      ~salt_length:(List.length tk / 2)
    |> Option.get
    |> List.to_seq
    |> String.of_seq
  ;;

  let apply_middlewares handler =
    let csrf_middleware = Middleware.m () in
    let session_middleware = SessionMiddleware.m () in
    let form_parser_middleware = Sihl_web.Middleware.Form_parser.m () in
    handler
    |> Rock.Middleware.apply csrf_middleware
    |> Rock.Middleware.apply session_middleware
    |> Rock.Middleware.apply form_parser_middleware
  ;;

  let get_request_yields_token _ () =
    let* () = Sihl_persistence.Repository.clean_all () in
    let req = Opium.Request.get "" in
    let handler req =
      let token_value = Sihl_web.Middleware.Csrf.find req in
      Alcotest.(check bool "Has CSRF token" true (not @@ String.equal "" token_value));
      Lwt.return @@ Opium.Response.of_plain_text ""
    in
    let wrapped_handler = apply_middlewares handler in
    let* _ = wrapped_handler req in
    Lwt.return ()
  ;;

  let get_request_without_token_succeeds _ () =
    let* () = Sihl_persistence.Repository.clean_all () in
    let req = Opium.Request.get "" in
    let handler _ = Lwt.return @@ Opium.Response.of_plain_text "" in
    let wrapped_handler = apply_middlewares handler in
    let* response = wrapped_handler req in
    let status = Opium.Response.status response |> Opium.Status.to_code in
    Alcotest.(check int "Has status 200" 200 status);
    Lwt.return ()
  ;;

  let two_get_requests_yield_same_token _ () =
    let* () = Sihl_persistence.Repository.clean_all () in
    (* Do GET to set a token *)
    let req = Opium.Request.get "" in
    let token_ref1 = ref "" in
    let token_ref2 = ref "" in
    let handler tkn req =
      tkn := Sihl_web.Middleware.Csrf.find req;
      Lwt.return @@ Opium.Response.of_plain_text ""
    in
    let wrapped_handler1 = apply_middlewares (handler token_ref1) in
    let* response = wrapped_handler1 req in
    let cookie = response |> Opium.Response.cookies |> List.hd in
    let status = Opium.Response.status response |> Opium.Status.to_code in
    Alcotest.(check int "Has status 200" 200 status);
    (* Do GET with session to get token *)
    let get_req =
      Opium.Request.get "/foo" |> Opium.Request.add_cookie cookie.Opium.Cookie.value
    in
    let wrapped_handler2 = apply_middlewares (handler token_ref2) in
    let* _ = wrapped_handler2 get_req in
    Alcotest.(
      check string "Same CSRF secret" (get_secret !token_ref1) (get_secret !token_ref2));
    Lwt.return ()
  ;;

  let post_request_yields_token _ () =
    let* () = Sihl_persistence.Repository.clean_all () in
    let post_req = Opium.Request.of_urlencoded ~body:[] "/foo" `POST in
    let handler req =
      let token_value = Sihl_web.Middleware.Csrf.find req in
      Alcotest.(check bool "Has CSRF token" true (not @@ String.equal "" token_value));
      Lwt.return @@ Opium.Response.of_plain_text ""
    in
    let wrapped_handler = apply_middlewares handler in
    let* _ = wrapped_handler post_req in
    Lwt.return ()
  ;;

  let post_request_without_token_fails _ () =
    let* () = Sihl_persistence.Repository.clean_all () in
    let post_req = Opium.Request.of_urlencoded ~body:[] "/foo" `POST in
    let handler _ = Lwt.return @@ Opium.Response.of_plain_text "" in
    let wrapped_handler = apply_middlewares handler in
    let* response = wrapped_handler post_req in
    let status = Opium.Response.status response |> Opium.Status.to_code in
    Alcotest.(check int "Has status 403" 403 status);
    Lwt.return ()
  ;;

  let post_request_with_invalid_b64_token_fails _ () =
    let* () = Sihl_persistence.Repository.clean_all () in
    let post_req =
      Opium.Request.of_urlencoded ~body:[ "csrf", [ "invalid_token" ] ] "/foo" `POST
    in
    let handler _ = Lwt.return @@ Opium.Response.of_plain_text "" in
    let wrapped_handler = apply_middlewares handler in
    Lwt.catch
      (fun () -> wrapped_handler post_req |> Lwt.map ignore)
      (function
        | Sihl_web.Middleware.Csrf.Crypto_failed txt ->
          Alcotest.(
            check string "Raises" "Failed to decode CSRF token. Wrong padding" txt);
          Lwt.return ()
        | exn -> Lwt.fail exn)
  ;;

  let post_request_with_invalid_token_fails _ () =
    let post_req =
      Opium.Request.of_urlencoded ~body:[ "csrf", [ "aGVsbG8=" ] ] "/foo" `POST
    in
    let* () = Sihl_persistence.Repository.clean_all () in
    let handler _ = Lwt.return @@ Opium.Response.of_plain_text "" in
    let wrapped_handler = apply_middlewares handler in
    Lwt.catch
      (fun () -> wrapped_handler post_req |> Lwt.map ignore)
      (function
        | Sihl_web.Middleware.Csrf.Crypto_failed txt ->
          Alcotest.(check string "Raises" "Failed to decrypt CSRF token" txt);
          Lwt.return ()
        | exn -> Lwt.fail exn)
  ;;

  let post_request_with_nonmatching_token_fails _ () =
    (* Do GET to set a token *)
    let req = Opium.Request.get "" in
    let* () = Sihl_persistence.Repository.clean_all () in
    let token_ref = ref "" in
    let handler req =
      token_ref := Sihl_web.Middleware.Csrf.find req;
      Lwt.return @@ Opium.Response.of_plain_text ""
    in
    let wrapped_handler = apply_middlewares handler in
    let* _ = wrapped_handler req in
    (* New request with new session but using old token *)
    let post_req =
      Opium.Request.of_urlencoded ~body:[ "csrf", [ !token_ref ] ] "/foo" `POST
    in
    let handler _ = Lwt.return @@ Opium.Response.of_plain_text "" in
    let wrapped_handler = apply_middlewares handler in
    let* response = wrapped_handler post_req in
    let status = Opium.Response.status response |> Opium.Status.to_code in
    Alcotest.(check int "Has status 403" 403 status);
    Lwt.return ()
  ;;

  let post_request_with_nonexisting_token_fails _ () =
    let post_req =
      Opium.Request.of_urlencoded
        ~body:
          [ ( "csrf"
            , [ "qMC8_WY0Kfjxmq5y7vFu2Po8ZsZcW5nocPVkc9Dwj60sZU-8oszGNIKiLKq4WQSuAxXxqxalLU4="
              ] )
          ]
        "/foo"
        `POST
    in
    let* () = Sihl_persistence.Repository.clean_all () in
    let handler _ = Lwt.return @@ Opium.Response.of_plain_text "" in
    let wrapped_handler = apply_middlewares handler in
    let* response = wrapped_handler post_req in
    let status = Opium.Response.status response |> Opium.Status.to_code in
    Alcotest.(check int "Has status 403" 403 status);
    Lwt.return ()
  ;;

  let post_request_with_valid_token_succeeds _ () =
    (* Do GET to set a token *)
    let req = Opium.Request.get "" in
    let* () = Sihl_persistence.Repository.clean_all () in
    let token_ref1 = ref "" in
    let token_ref2 = ref "" in
    let handler tkn req =
      tkn := Sihl_web.Middleware.Csrf.find req;
      Lwt.return @@ Opium.Response.of_plain_text ""
    in
    let wrapped_handler = apply_middlewares @@ handler token_ref1 in
    let* response = wrapped_handler req in
    let cookie = response |> Opium.Response.cookies |> List.hd in
    let status = Opium.Response.status response |> Opium.Status.to_code in
    Alcotest.(check int "Has status 200" 200 status);
    (* Do POST to use created token *)
    let post_req =
      Opium.Request.of_urlencoded ~body:[ "csrf", [ !token_ref1 ] ] "/foo" `POST
      |> Opium.Request.add_cookie cookie.Opium.Cookie.value
    in
    let wrapped_handler = apply_middlewares @@ handler token_ref2 in
    let* response = wrapped_handler post_req in
    let status = Opium.Response.status response |> Opium.Status.to_code in
    Alcotest.(check int "Has status 200" 200 status);
    let* token = TokenService.find_opt !token_ref1 in
    Alcotest.(check (option token_alco) "Token is invalidated" None token);
    Lwt.return ()
  ;;

  let two_post_requests_succeed _ () =
    (* Do GET to set a token *)
    let req = Opium.Request.get "" in
    let* () = Sihl_persistence.Repository.clean_all () in
    let token_ref1 = ref "" in
    let token_ref2 = ref "" in
    let token_ref3 = ref "" in
    let handler tkn req =
      tkn := Sihl_web.Middleware.Csrf.find req;
      Lwt.return @@ Opium.Response.of_plain_text ""
    in
    let wrapped_handler = apply_middlewares @@ handler token_ref1 in
    let* response = wrapped_handler req in
    let cookie = response |> Opium.Response.cookies |> List.hd in
    let status = Opium.Response.status response |> Opium.Status.to_code in
    Alcotest.(check int "Has status 200" 200 status);
    (* Do first POST *)
    let post_req =
      Opium.Request.of_urlencoded
        ~body:[ "csrf", [ Uri.pct_encode !token_ref1 ] ]
        "/foo"
        `POST
      |> Opium.Request.add_cookie cookie.Opium.Cookie.value
    in
    let wrapped_handler = apply_middlewares @@ handler token_ref2 in
    let* response = wrapped_handler post_req in
    let status = Opium.Response.status response |> Opium.Status.to_code in
    Alcotest.(check int "Has status 200" 200 status);
    let* token = TokenService.find_opt !token_ref1 in
    Alcotest.(check (option token_alco) "Token is invalidated" None token);
    (* Do second POST *)
    (* TODO [aerben] do opium everywhere *)
    Alcotest.(
      check
        bool
        "New token generated after POST"
        false
        (String.equal (get_secret !token_ref1) (get_secret !token_ref2)));
    let post_req =
      Opium.Request.of_urlencoded
        ~body:[ "csrf", [ Uri.pct_encode !token_ref2 ] ]
        "/foo"
        `POST
      |> Opium.Request.add_cookie @@ cookie.Opium.Cookie.value
    in
    let wrapped_handler = apply_middlewares @@ handler token_ref3 in
    let* response = wrapped_handler post_req in
    let status = Opium.Response.status response |> Opium.Status.to_code in
    Alcotest.(check int "Has status 200" 200 status);
    let* token = TokenService.find_opt !token_ref2 in
    Alcotest.(check (option token_alco) "Token is invalidated" None token);
    Lwt.return ()
  ;;

  let suite =
    [ ( "csrf"
      , [ test_case "get request yields CSRF token" `Quick get_request_yields_token
        ; test_case
            "two get requests yield same CSRF token"
            `Quick
            two_get_requests_yield_same_token
        ; test_case
            "get request without CSRF token succeeds"
            `Quick
            get_request_without_token_succeeds
        ; test_case "post request yields CSRF token" `Quick post_request_yields_token
        ; test_case
            "post request without CSRF token fails"
            `Quick
            post_request_without_token_fails
        ; test_case
            "post request with invalid b64 CSRF token fails"
            `Quick
            post_request_with_invalid_b64_token_fails
        ; test_case
            "post request with invalid CSRF token fails"
            `Quick
            post_request_with_invalid_token_fails
        ; test_case
            "post request with non-matching CSRF token fails"
            `Quick
            post_request_with_nonmatching_token_fails
        ; test_case
            "post request with non-existing CSRF token fails"
            `Quick
            post_request_with_nonexisting_token_fails
        ; test_case
            "post request with valid CSRF token succeeds"
            `Quick
            post_request_with_valid_token_succeeds
        ; test_case
            "two post requests with a valid CSRF token succeed"
            `Quick
            two_post_requests_succeed
        ] )
    ]
  ;;
end
