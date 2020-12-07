open Alcotest_lwt
open Lwt.Syntax

module Make
    (TokenService : Sihl_contract.Token.Sig)
    (SessionService : Sihl_contract.Session.Sig) =
struct
  module Middleware = Sihl_web.Middleware.Csrf.Make (TokenService) (SessionService)
  module SessionMiddleware = Sihl_web.Middleware.Session.Make (SessionService)

  let apply_middlewares handler =
    let csrf_middleware = Middleware.m () in
    let session_middleware = SessionMiddleware.m () in
    let urlencoded_middleware = Sihl_web.Middleware.Urlencoded.m () in
    handler
    |> Rock.Middleware.apply csrf_middleware
    |> Rock.Middleware.apply session_middleware
    |> Rock.Middleware.apply urlencoded_middleware
  ;;

  let get_request_yields_token _ () =
    let req = Sihl_type.Http_request.get "" in
    let* () = Sihl_persistence.Repository.clean_all () in
    let handler req =
      let token_value = Sihl_web.Middleware.Csrf.find req in
      Alcotest.(check bool "Has CSRF token" true (not @@ String.equal "" token_value));
      Lwt.return @@ Sihl_type.Http_response.of_plain_text ""
    in
    let wrapped_handler = apply_middlewares handler in
    let* _ = wrapped_handler req in
    Lwt.return ()
  ;;

  let get_request_without_token_succeeds _ () =
    let req = Sihl_type.Http_request.get "" in
    let* () = Sihl_persistence.Repository.clean_all () in
    let handler _ = Lwt.return @@ Sihl_type.Http_response.of_plain_text "" in
    let wrapped_handler = apply_middlewares handler in
    let* response = wrapped_handler req in
    let status = Sihl_type.Http_response.status response |> Opium.Status.to_code in
    Alcotest.(check int "Has status 200" 200 status);
    Lwt.return ()
  ;;

  let two_get_requests_yield_same_token _ () =
    let req = Sihl_type.Http_request.get "" in
    let* () = Sihl_persistence.Repository.clean_all () in
    let token_ref1 = ref "" in
    let token_ref2 = ref "" in
    let handler tkn req =
      tkn := Sihl_web.Middleware.Csrf.find req;
      Lwt.return @@ Sihl_type.Http_response.of_plain_text ""
    in
    let wrapped_handler1 = apply_middlewares (handler token_ref1) in
    (* Do GET to create token *)
    let* response = wrapped_handler1 req in
    let cookie = response |> Sihl_type.Http_response.cookies |> List.hd in
    let cookie_key, cookie_value = cookie.Opium.Cookie.value in
    let status = Sihl_type.Http_response.status response |> Opium.Status.to_code in
    Alcotest.(check int "Has status 200" 200 status);
    (* Do GET with session to get token *)
    let get_req =
      Sihl_type.Http_request.get "/foo"
      |> Sihl_type.Http_request.add_cookie (cookie_key, cookie_value)
    in
    let wrapped_handler2 = apply_middlewares (handler token_ref2) in
    let* _ = wrapped_handler2 get_req in
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
    in
    Alcotest.(
      check string "Same CSRF secret" (get_secret !token_ref1) (get_secret !token_ref2));
    Lwt.return ()
  ;;

  let post_request_yields_token _ () =
    let post_req = Sihl_type.Http_request.post "/foo" in
    let* () = Sihl_persistence.Repository.clean_all () in
    let handler req =
      let token_value = Sihl_web.Middleware.Csrf.find req in
      Alcotest.(check bool "Has CSRF token" true (not @@ String.equal "" token_value));
      Lwt.return @@ Sihl_type.Http_response.of_plain_text ""
    in
    let wrapped_handler = apply_middlewares handler in
    let* _ = wrapped_handler post_req in
    Lwt.return ()
  ;;

  let post_request_without_token_fails _ () =
    let post_req = Sihl_type.Http_request.post "/foo" in
    let* () = Sihl_persistence.Repository.clean_all () in
    let handler _ = Lwt.return @@ Sihl_type.Http_response.of_plain_text "" in
    let wrapped_handler = apply_middlewares handler in
    let* response = wrapped_handler post_req in
    let status = Sihl_type.Http_response.status response |> Opium.Status.to_code in
    Alcotest.(check int "Has status 403" 403 status);
    Lwt.return ()
  ;;

  let post_request_with_invalid_b64_token_fails _ () =
    let post_req =
      Sihl_type.Http_request.of_urlencoded
        ~body:[ "csrf", [ "invalid_token" ] ]
        "/foo"
        `POST
    in
    let* () = Sihl_persistence.Repository.clean_all () in
    let handler _ = Lwt.return @@ Sihl_type.Http_response.of_plain_text "" in
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
      Sihl_type.Http_request.of_urlencoded ~body:[ "csrf", [ "aGVsbG8=" ] ] "/foo" `POST
    in
    let* () = Sihl_persistence.Repository.clean_all () in
    let handler _ = Lwt.return @@ Sihl_type.Http_response.of_plain_text "" in
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
    let req = Sihl_type.Http_request.get "" in
    let* () = Sihl_persistence.Repository.clean_all () in
    let token_ref = ref "" in
    let handler req =
      token_ref := Sihl_web.Middleware.Csrf.find req;
      Lwt.return @@ Sihl_type.Http_response.of_plain_text ""
    in
    (* Do GET to create token *)
    let wrapped_handler = apply_middlewares handler in
    let* _ = wrapped_handler req in
    (* New request with new session but using old token *)
    let post_req =
      Sihl_type.Http_request.of_urlencoded ~body:[ "csrf", [ !token_ref ] ] "/foo" `POST
    in
    let handler _ = Lwt.return @@ Sihl_type.Http_response.of_plain_text "" in
    let wrapped_handler = apply_middlewares handler in
    let* response = wrapped_handler post_req in
    let status = Sihl_type.Http_response.status response |> Opium.Status.to_code in
    Alcotest.(check int "Has status 403" 403 status);
    Lwt.return ()
  ;;

  let post_request_with_nonexisting_token_fails _ () =
    let post_req =
      Sihl_type.Http_request.of_urlencoded
        ~body:
          [ ( "csrf"
            , [ "qMC8_WY0Kfjxmq5y7vFu2Po8ZsZcW5nocPVkc9Dwj60sZU-8oszGNIKiLKq4WQSuAxXxqxalLU4="
              ] )
          ]
        "/foo"
        `POST
    in
    let* () = Sihl_persistence.Repository.clean_all () in
    let handler _ = Lwt.return @@ Sihl_type.Http_response.of_plain_text "" in
    let wrapped_handler = apply_middlewares handler in
    let* response = wrapped_handler post_req in
    let status = Sihl_type.Http_response.status response |> Opium.Status.to_code in
    Alcotest.(check int "Has status 403" 403 status);
    Lwt.return ()
  ;;

  let post_request_with_valid_token_succeeds _ () =
    (* Do GET to set a token *)
    let req = Sihl_type.Http_request.get "" in
    let* () = Sihl_persistence.Repository.clean_all () in
    let token_ref = ref "" in
    let session_req = ref None in
    let handler req =
      session_req := Some req;
      token_ref := Sihl_web.Middleware.Csrf.find req;
      Lwt.return @@ Sihl_type.Http_response.of_plain_text ""
    in
    (* Do GET to create token *)
    let wrapped_handler = apply_middlewares handler in
    let* response = wrapped_handler req in
    let cookie = response |> Sihl_type.Http_response.cookies |> List.hd in
    let cookie_key, cookie_value = cookie.Opium.Cookie.value in
    let cookie_header = "Cookie", Format.sprintf "%s=%s" cookie_key cookie_value in
    let status = Sihl_type.Http_response.status response |> Opium.Status.to_code in
    Alcotest.(check int "Has status 200" 200 status);
    (* Do POST to use created token *)
    let body = Uri.pct_encode @@ "csrf=" ^ !token_ref in
    let post_req =
      Sihl_type.Http_request.of_plain_text ~body "/foo" `POST
      |> Sihl_type.Http_request.add_header cookie_header
    in
    let wrapped_handler = apply_middlewares handler in
    let* response = wrapped_handler post_req in
    let status = Sihl_type.Http_response.status response |> Opium.Status.to_code in
    Alcotest.(check int "Has status 200" 200 status);
    let req = Option.get !session_req in
    let session = Sihl_web.Middleware.Session.find req in
    let* token_id = SessionService.find_value session "csrf" in
    let token_id = Option.get token_id in
    let* token = TokenService.find_by_id_opt token_id in
    Alcotest.(check (option Sihl_type.Token.alco) "Token is invalidated" None token);
    Lwt.return ()
  ;;

  let suite =
    [ ( "csrf"
      , [ test_case "get request yields CSRF token" `Quick get_request_yields_token
        ; test_case
            "two get requests_yield_same_token"
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
        ] )
    ]
  ;;
end
