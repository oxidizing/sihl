open Alcotest_lwt
open Lwt.Syntax

module Make
    (TokenService : Sihl.Token.Sig.SERVICE)
    (SessionService : Sihl.Session.Sig.SERVICE) =
struct
  module Middleware = Sihl.Middleware.Csrf.Make (TokenService) (SessionService)
  module SessionMiddleware = Sihl.Middleware.Session.Make (SessionService)

  let apply_middlewares handler =
    let middleware = Middleware.m () in
    let session_middleware = SessionMiddleware.m () in
    handler
    |> Opium_kernel.Rock.Middleware.apply middleware
    |> Opium_kernel.Rock.Middleware.apply session_middleware
  ;;

  let get_request_yields_token _ () =
    let req = Sihl.Http.Request.get "" in
    let ctx = Sihl.Http.Request.to_ctx req in
    let* () = Sihl.Repository.Service.clean_all ctx in
    let handler req =
      let token_value = Sihl.Middleware.Csrf.find req in
      Alcotest.(check bool "Has CSRF token" true (not @@ String.equal "" token_value));
      Lwt.return @@ Sihl.Http.Response.create ()
    in
    let wrapped_handler = apply_middlewares handler in
    let* _ = wrapped_handler req in
    Lwt.return ()
  ;;

  let get_request_without_token_succeeds _ () =
    let req = Sihl.Http.Request.get "" in
    let ctx = Sihl.Http.Request.to_ctx req in
    let* () = Sihl.Repository.Service.clean_all ctx in
    let handler _ = Lwt.return @@ Sihl.Http.Response.create () in
    let wrapped_handler = apply_middlewares handler in
    let* response = wrapped_handler req in
    let status = Sihl.Http.Response.status response in
    Alcotest.(check int "Has status 200" 200 status);
    Lwt.return ()
  ;;

  let two_get_requests_yield_same_token _ () =
    let req = Sihl.Http.Request.get "" in
    let ctx = Sihl.Http.Request.to_ctx req in
    let* () = Sihl.Repository.Service.clean_all ctx in
    let token_ref1 = ref "" in
    let token_ref2 = ref "" in
    let handler tkn req =
      tkn := Sihl.Middleware.Csrf.find req;
      Lwt.return @@ Sihl.Http.Response.create ()
    in
    let wrapped_handler1 = apply_middlewares (handler token_ref1) in
    (* Do GET to create token *)
    let* response = wrapped_handler1 req in
    let cookie_key, cookie_value =
      response |> Sihl.Http.Response.cookies |> List.hd |> Sihl.Http.Cookie.value
    in
    let cookie_header = "Cookie", Format.sprintf "%s=%s" cookie_key cookie_value in
    let status = Sihl.Http.Response.status response in
    Alcotest.(check int "Has status 200" 200 status);
    (* Do GET with session to get token *)
    let get_req =
      Sihl.Http.Request.get "/foo" |> Sihl.Http.Request.add_header cookie_header
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
      Sihl.Utils.Encryption.decrypt_with_salt
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
    let post_req = Sihl.Http.Request.post "/foo" in
    let ctx = Sihl.Http.Request.to_ctx post_req in
    let* () = Sihl.Repository.Service.clean_all ctx in
    let handler req =
      let token_value = Sihl.Middleware.Csrf.find req in
      Alcotest.(check bool "Has CSRF token" true (not @@ String.equal "" token_value));
      Lwt.return @@ Sihl.Http.Response.create ()
    in
    let wrapped_handler = apply_middlewares handler in
    let* _ = wrapped_handler post_req in
    Lwt.return ()
  ;;

  let post_request_without_token_fails _ () =
    let post_req = Sihl.Http.Request.post "/foo" in
    let ctx = Sihl.Http.Request.to_ctx post_req in
    let* () = Sihl.Repository.Service.clean_all ctx in
    let handler _ = Lwt.return @@ Sihl.Http.Response.create () in
    let wrapped_handler = apply_middlewares handler in
    let* response = wrapped_handler post_req in
    let status = Sihl.Http.Response.status response in
    Alcotest.(check int "Has status 403" 403 status);
    Lwt.return ()
  ;;

  let post_request_with_invalid_b64_token_fails _ () =
    let post_req =
      Sihl.Http.Request.of_urlencoded ~body:[ "csrf", [ "invalid_token" ] ] "/foo" `POST
    in
    let ctx = Sihl.Http.Request.to_ctx post_req in
    let* () = Sihl.Repository.Service.clean_all ctx in
    let handler _ = Lwt.return @@ Sihl.Http.Response.create () in
    let wrapped_handler = apply_middlewares handler in
    Lwt.catch
      (fun () -> wrapped_handler post_req |> Lwt.map ignore)
      (function
        | Sihl.Middleware.Csrf.Crypto_failed txt ->
          Alcotest.(
            check string "Raises" "Failed to decode CSRF token. Wrong padding" txt);
          Lwt.return ()
        | exn -> Lwt.fail exn)
  ;;

  let post_request_with_invalid_token_fails _ () =
    let post_req =
      Sihl.Http.Request.of_urlencoded ~body:[ "csrf", [ "aGVsbG8=" ] ] "/foo" `POST
    in
    let ctx = Sihl.Http.Request.to_ctx post_req in
    let* () = Sihl.Repository.Service.clean_all ctx in
    let handler _ = Lwt.return @@ Sihl.Http.Response.create () in
    let wrapped_handler = apply_middlewares handler in
    Lwt.catch
      (fun () -> wrapped_handler post_req |> Lwt.map ignore)
      (function
        | Sihl.Middleware.Csrf.Crypto_failed txt ->
          Alcotest.(check string "Raises" "Failed to decrypt CSRF token" txt);
          Lwt.return ()
        | exn -> Lwt.fail exn)
  ;;

  let post_request_with_nonmatching_token_fails _ () =
    let req = Sihl.Http.Request.get "" in
    let ctx = Sihl.Http.Request.to_ctx req in
    let* () = Sihl.Repository.Service.clean_all ctx in
    let token_ref = ref "" in
    let handler req =
      token_ref := Sihl.Middleware.Csrf.find req;
      Lwt.return @@ Sihl.Http.Response.create ()
    in
    (* Do GET to create token *)
    let wrapped_handler = apply_middlewares handler in
    let* _ = wrapped_handler req in
    (* New request with new session but using old token *)
    let post_req =
      Sihl.Http.Request.of_urlencoded ~body:[ "csrf", [ !token_ref ] ] "/foo" `POST
    in
    let handler _ = Lwt.return @@ Sihl.Http.Response.create () in
    let wrapped_handler = apply_middlewares handler in
    let* response = wrapped_handler post_req in
    let status = Sihl.Http.Response.status response in
    Alcotest.(check int "Has status 403" 403 status);
    Lwt.return ()
  ;;

  let post_request_with_nonexisting_token_fails _ () =
    let post_req =
      Sihl.Http.Request.of_urlencoded
        ~body:
          [ ( "csrf"
            , [ "qMC8_WY0Kfjxmq5y7vFu2Po8ZsZcW5nocPVkc9Dwj60sZU-8oszGNIKiLKq4WQSuAxXxqxalLU4="
              ] )
          ]
        "/foo"
        `POST
    in
    let ctx = Sihl.Http.Request.to_ctx post_req in
    let* () = Sihl.Repository.Service.clean_all ctx in
    let handler _ = Lwt.return @@ Sihl.Http.Response.create () in
    let wrapped_handler = apply_middlewares handler in
    let* response = wrapped_handler post_req in
    let status = Sihl.Http.Response.status response in
    Alcotest.(check int "Has status 403" 403 status);
    Lwt.return ()
  ;;

  let post_request_with_valid_token_succeeds _ () =
    (* Do GET to set a token *)
    let req = Sihl.Http.Request.get "" in
    let ctx = Sihl.Http.Request.to_ctx req in
    let* () = Sihl.Repository.Service.clean_all ctx in
    let token_ref = ref "" in
    let session_req = ref None in
    let handler req =
      session_req := Some req;
      token_ref := Sihl.Middleware.Csrf.find req;
      Lwt.return @@ Sihl.Http.Response.create ()
    in
    (* Do GET to create token *)
    let wrapped_handler = apply_middlewares handler in
    let* response = wrapped_handler req in
    let cookie_key, cookie_value =
      response |> Sihl.Http.Response.cookies |> List.hd |> Sihl.Http.Cookie.value
    in
    let cookie_header = "Cookie", Format.sprintf "%s=%s" cookie_key cookie_value in
    let status = Sihl.Http.Response.status response in
    Alcotest.(check int "Has status 200" 200 status);
    (* Do POST to use created token *)
    let body = Uri.pct_encode @@ "csrf=" ^ !token_ref in
    let post_req =
      Sihl.Http.Request.of_plain_text ~body "/foo" `POST
      |> Sihl.Http.Request.add_header cookie_header
    in
    let wrapped_handler = apply_middlewares handler in
    let* response = wrapped_handler post_req in
    let status = Sihl.Http.Response.status response in
    Alcotest.(check int "Has status 200" 200 status);
    let req = Option.get !session_req in
    let session = Sihl.Middleware.Session.find req in
    let token_id = Sihl.Session.get "csrf" session in
    let token_id = Option.get token_id in
    let* token = TokenService.find_by_id_opt ctx token_id in
    Alcotest.(check (option Sihl.Token.alco) "Token is invalidated" None token);
    Lwt.return ()
  ;;

  let test_suite =
    ( "csrf"
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
  ;;
end
