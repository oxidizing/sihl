open Alcotest_lwt
open Lwt.Syntax

(* TODO [aerben] FIX TESTS*)

module Make
    (TokenService : Sihl.Token.Sig.SERVICE)
    (SessionService : Sihl.Session.Sig.SERVICE)
    (RandomService : Sihl.Random.Sig.SERVICE) =
struct
  module Middleware =
    Sihl.Web.Middleware.Csrf.Make (TokenService) (SessionService) (RandomService)

  module SessionMiddleware = Sihl.Web.Middleware.Session.Make (SessionService)

  let apply_middlewares handler =
    let middleware = Middleware.m () in
    let session_middleware = SessionMiddleware.m () in
    handler
    |> Sihl.Web.Middleware.apply middleware
    |> Sihl.Web.Middleware.apply session_middleware
  ;;

  let get_request_yields_token _ () =
    let ctx = Sihl.Core.Ctx.empty |> Sihl.Web.Req.create_and_add_to_ctx in
    let* () = Sihl.Repository.Service.clean_all ctx in
    let handler ctx =
      let token = Sihl.Web.Middleware.Csrf.get_token ctx in
      let token_value = Option.get token in
      Alcotest.(check bool "Has CSRF token" true (not @@ String.equal "" token_value));
      Lwt.return @@ Sihl.Web.Res.html
    in
    let wrapped_handler = apply_middlewares handler in
    let* _ = wrapped_handler ctx in
    Lwt.return ()
  ;;

  let get_request_without_token_succeeds _ () =
    let ctx = Sihl.Core.Ctx.empty |> Sihl.Web.Req.create_and_add_to_ctx in
    let* () = Sihl.Repository.Service.clean_all ctx in
    let handler _ = Lwt.return @@ Sihl.Web.Res.html in
    let wrapped_handler = apply_middlewares handler in
    let* response = wrapped_handler ctx in
    let status = Sihl.Web.Res.status response in
    Alcotest.(check int "Has status 200" 200 status);
    Lwt.return ()
  ;;

  let two_get_requests_yield_same_token _ () =
    let ctx = Sihl.Core.Ctx.empty |> Sihl.Web.Req.create_and_add_to_ctx in
    let* () = Sihl.Repository.Service.clean_all ctx in
    let token_ref1 = ref "" in
    let token_ref2 = ref "" in
    let handler tkn ctx =
      let token = Sihl.Web.Middleware.Csrf.get_token ctx in
      tkn := Option.get token;
      Lwt.return Sihl.Web.Res.html
    in
    let wrapped_handler1 = apply_middlewares (handler token_ref1) in
    (* Do GET to create token *)
    let* response = wrapped_handler1 ctx in
    let cookie_key, cookie_value = response |> Sihl.Web.Res.cookies |> List.hd in
    let cookie_header = "Cookie", Format.sprintf "%s=%s" cookie_key cookie_value in
    let status = Sihl.Web.Res.status response in
    Alcotest.(check int "Has status 200" 200 status);
    (* Do GET with session to get token *)
    let get_req =
      Opium.Std.Request.create
        (Cohttp_lwt.Request.make
           ~headers:(Cohttp.Header.of_list [ cookie_header ])
           (Uri.of_string "/foo"))
    in
    let ctx = ctx |> Sihl.Web.Req.add_to_ctx get_req in
    let wrapped_handler2 = apply_middlewares (handler token_ref2) in
    let* _ = wrapped_handler2 ctx in
    let get_secret tk =
      tk
      |> Base64.decode ~alphabet:Base64.uri_safe_alphabet
      |> Result.get_ok
      |> Utils.String.string_to_char_list
      |> fun tk ->
      Utils.Encryption.decrypt_with_salt
        ~salted_cipher:tk
        ~salt_length:(List.length tk / 2)
      |> Option.get
      |> Utils.String.char_list_to_string
    in
    Alcotest.(
      check string "Same CSRF secret" (get_secret !token_ref1) (get_secret !token_ref2));
    Lwt.return ()
  ;;

  let post_request_yields_token _ () =
    let post_req =
      Opium.Std.Request.create
        ~body:(Cohttp_lwt.Body.of_string "")
        (Cohttp_lwt.Request.make ~meth:`POST (Uri.of_string "/foo"))
    in
    let ctx = Sihl.Core.Ctx.empty |> Sihl.Web.Req.add_to_ctx post_req in
    let* () = Sihl.Repository.Service.clean_all ctx in
    let handler ctx =
      let token = Sihl.Web.Middleware.Csrf.get_token ctx in
      let token_value = Option.get token in
      Alcotest.(check bool "Has CSRF token" true (not @@ String.equal "" token_value));
      Lwt.return @@ Sihl.Web.Res.html
    in
    let wrapped_handler = apply_middlewares handler in
    let* _ = wrapped_handler ctx in
    Lwt.return ()
  ;;

  let post_request_without_token_fails _ () =
    let post_req =
      Opium.Std.Request.create
        (Cohttp_lwt.Request.make ~meth:`POST (Uri.of_string "/foo"))
    in
    let ctx = Sihl.Core.Ctx.empty |> Sihl.Web.Req.add_to_ctx post_req in
    let* () = Sihl.Repository.Service.clean_all ctx in
    let handler _ = Lwt.return @@ Sihl.Web.Res.html in
    let wrapped_handler = apply_middlewares handler in
    let* response = wrapped_handler ctx in
    let status = Sihl.Web.Res.status response in
    Alcotest.(check int "Has status 403" 403 status);
    Lwt.return ()
  ;;

  let post_request_with_invalid_b64_token_fails _ () =
    let post_req =
      Opium.Std.Request.create
        ~body:(Cohttp_lwt.Body.of_string "csrf=invalid_token")
        (Cohttp_lwt.Request.make ~meth:`POST (Uri.of_string "/foo"))
    in
    let ctx = Sihl.Core.Ctx.empty |> Sihl.Web.Req.add_to_ctx post_req in
    let* () = Sihl.Repository.Service.clean_all ctx in
    let handler _ = Lwt.return @@ Sihl.Web.Res.html in
    let wrapped_handler = apply_middlewares handler in
    Lwt.catch
      (fun () -> wrapped_handler ctx |> Lwt.map ignore)
      (function
        | Sihl.Web.Middleware.Csrf.Crypto_failed txt ->
          Alcotest.(
            check string "Raises" "Failed to decode CSRF token. Wrong padding" txt);
          Lwt.return ()
        | exn -> Lwt.fail exn)
  ;;

  let post_request_with_invalid_token_fails _ () =
    let post_req =
      Opium.Std.Request.create
        ~body:(Cohttp_lwt.Body.of_string "csrf=aGVsbG8=")
        (Cohttp_lwt.Request.make ~meth:`POST (Uri.of_string "/foo"))
    in
    let ctx = Sihl.Core.Ctx.empty |> Sihl.Web.Req.add_to_ctx post_req in
    let* () = Sihl.Repository.Service.clean_all ctx in
    let handler _ = Lwt.return @@ Sihl.Web.Res.html in
    let wrapped_handler = apply_middlewares handler in
    Lwt.catch
      (fun () -> wrapped_handler ctx |> Lwt.map ignore)
      (function
        | Sihl.Web.Middleware.Csrf.Crypto_failed txt ->
          Alcotest.(check string "Raises" "Failed to decrypt CSRF token" txt);
          Lwt.return ()
        | exn -> Lwt.fail exn)
  ;;

  let post_request_with_nonmatching_token_fails _ () =
    let ctx = Sihl.Core.Ctx.empty |> Sihl.Web.Req.create_and_add_to_ctx in
    let* () = Sihl.Repository.Service.clean_all ctx in
    let token_ref = ref "" in
    let handler ctx =
      let token = Sihl.Web.Middleware.Csrf.get_token ctx in
      token_ref := Option.get token;
      Lwt.return Sihl.Web.Res.html
    in
    (* Do GET to create token *)
    let wrapped_handler = apply_middlewares handler in
    let* _ = wrapped_handler ctx in
    (* New request with new session but using old token *)
    let post_req =
      Opium.Std.Request.create
        ~body:(Cohttp_lwt.Body.of_string ("csrf=" ^ !token_ref))
        (Cohttp_lwt.Request.make ~meth:`POST (Uri.of_string "/foo"))
    in
    let ctx = Sihl.Core.Ctx.empty |> Sihl.Web.Req.add_to_ctx post_req in
    let handler _ = Lwt.return @@ Sihl.Web.Res.html in
    let wrapped_handler = apply_middlewares handler in
    let* response = wrapped_handler ctx in
    let status = Sihl.Web.Res.status response in
    Alcotest.(check int "Has status 403" 403 status);
    Lwt.return ()
  ;;

  let post_request_with_nonexisting_token_fails _ () =
    let post_req =
      Opium.Std.Request.create
        ~body:
          (Cohttp_lwt.Body.of_string
             "csrf=qMC8_WY0Kfjxmq5y7vFu2Po8ZsZcW5nocPVkc9Dwj60sZU-8oszGNIKiLKq4WQSuAxXxqxalLU4=")
        (Cohttp_lwt.Request.make ~meth:`POST (Uri.of_string "/foo"))
    in
    let ctx = Sihl.Core.Ctx.empty |> Sihl.Web.Req.add_to_ctx post_req in
    let* () = Sihl.Repository.Service.clean_all ctx in
    let handler _ = Lwt.return @@ Sihl.Web.Res.html in
    let wrapped_handler = apply_middlewares handler in
    let* response = wrapped_handler ctx in
    let status = Sihl.Web.Res.status response in
    Alcotest.(check int "Has status 403" 403 status);
    Lwt.return ()
  ;;

  let post_request_with_valid_token_succeeds _ () =
    (* Do GET to set a token *)
    let ctx = Sihl.Core.Ctx.empty |> Sihl.Web.Req.create_and_add_to_ctx in
    let* () = Sihl.Repository.Service.clean_all ctx in
    let token_ref = ref "" in
    let session_ctx = ref None in
    let handler ctx =
      session_ctx := Some ctx;
      let token = Sihl.Web.Middleware.Csrf.get_token ctx in
      token_ref := Option.get token;
      Lwt.return Sihl.Web.Res.html
    in
    (* Do GET to create token *)
    let wrapped_handler = apply_middlewares handler in
    let* response = wrapped_handler ctx in
    let cookie_key, cookie_value = response |> Sihl.Web.Res.cookies |> List.hd in
    let cookie_header = "Cookie", Format.sprintf "%s=%s" cookie_key cookie_value in
    let status = Sihl.Web.Res.status response in
    Alcotest.(check int "Has status 200" 200 status);
    (* Do POST to use created token *)
    let body = Uri.pct_encode @@ "csrf=" ^ !token_ref in
    let post_req =
      Opium.Std.Request.create
        ~body:(Cohttp_lwt.Body.of_string body)
        (Cohttp_lwt.Request.make
           ~headers:(Cohttp.Header.of_list [ cookie_header ])
           ~meth:`POST
           (Uri.of_string "/foo"))
    in
    let ctx = ctx |> Sihl.Web.Req.add_to_ctx post_req in
    let handler _ = Lwt.return Sihl.Web.Res.html in
    let wrapped_handler = apply_middlewares handler in
    let* response = wrapped_handler ctx in
    let status = Sihl.Web.Res.status response in
    Alcotest.(check int "Has status 200" 200 status);
    let ctx = Option.get !session_ctx in
    let* token_id = SessionService.get ctx ~key:"csrf" in
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
