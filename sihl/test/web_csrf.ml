open Alcotest_lwt
open Lwt.Syntax

let apply_middlewares handler ?not_allowed_handler =
  handler
  |> Rock.Middleware.apply (Sihl.Web.Middleware.csrf ?not_allowed_handler ())
  |> Rock.Middleware.apply Sihl.Web.Middleware.form
;;

let get_request_without_token_succeeds _ () =
  let req = Opium.Request.get "" in
  let handler _ = Lwt.return @@ Opium.Response.of_plain_text "" in
  let wrapped_handler = apply_middlewares handler in
  let* response = wrapped_handler req in
  let status = Opium.Response.status response |> Opium.Status.to_code in
  Alcotest.(check int "Has status 200" 200 status);
  Lwt.return ()
;;

let get_request_yields_token _ () =
  let req = Opium.Request.get "" in
  let token_ref = ref "" in
  let handler req =
    token_ref := Sihl.Web.Csrf.find req;
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let wrapped_handler = apply_middlewares handler in
  let* response = wrapped_handler req in
  (* New hashed token set in cookie *)
  let csrf_cookie =
    Opium.Response.cookie "__Host-csrf" response |> Option.get
  in
  let _, value = csrf_cookie.Opium.Cookie.value in
  Alcotest.(check bool "Has CSRF token" true (String.length !token_ref > 0));
  Alcotest.(check bool "Has CSRF cookie" true (String.length value > 0));
  Lwt.return ()
;;

let two_get_requests_yield_different_token _ () =
  let req = Opium.Request.get "" in
  let token_ref1 = ref "" in
  let token_ref2 = ref "" in
  let handler tkn req =
    tkn := Sihl.Web.Csrf.find req;
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let wrapped_handler1 = apply_middlewares @@ handler token_ref1 in
  let* response = wrapped_handler1 req in
  let cookie = response |> Opium.Response.cookies |> List.hd in
  let status = Opium.Response.status response |> Opium.Status.to_code in
  Alcotest.(check int "Has status 200" 200 status);
  (* Do GET with cookie to get token *)
  let get_req =
    Opium.Request.get "/foo"
    |> Opium.Request.add_cookie cookie.Opium.Cookie.value
  in
  let wrapped_handler2 = apply_middlewares @@ handler token_ref2 in
  let* _ = wrapped_handler2 get_req in
  Alcotest.(
    check bool "First Has CSRF token" true (String.length !token_ref1 > 0));
  Alcotest.(
    check bool "Second Has CSRF token" true (String.length !token_ref2 > 0));
  Alcotest.(
    check
      bool
      "Different CSRF tokens"
      false
      (String.equal !token_ref1 !token_ref2));
  Lwt.return ()
;;

let post_request_yields_token _ () =
  let post_req = Opium.Request.of_urlencoded ~body:[] "/foo" `POST in
  let token_ref = ref "" in
  let not_allowed_handler req =
    token_ref := Sihl.Web.Csrf.find req;
    Alcotest.(check bool "Has CSRF token" true (String.length !token_ref > 0));
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let handler _ = Lwt.return @@ Opium.Response.of_plain_text "" in
  let wrapped_handler = apply_middlewares handler ~not_allowed_handler in
  let* response = wrapped_handler post_req in
  (* New hashed token set in cookie *)
  let csrf_cookie =
    Opium.Response.cookie "__Host-csrf" response |> Option.get
  in
  let _, value = csrf_cookie.Opium.Cookie.value in
  Alcotest.(check bool "Has CSRF token" true (String.length !token_ref > 0));
  Alcotest.(check bool "Has CSRF cookie" true (String.length value > 0));
  Lwt.return ()
;;

let two_post_requests_yield_different_token _ () =
  let req = Opium.Request.of_urlencoded ~body:[] "/foo" `POST in
  let token_ref1 = ref "" in
  let token_ref2 = ref "" in
  let not_allowed_handler tkn req =
    tkn := Sihl.Web.Csrf.find req;
    Lwt.return @@ Opium.Response.of_plain_text ~status:`Forbidden ""
  in
  let handler _ = Lwt.return @@ Opium.Response.of_plain_text "" in
  let wrapped_handler1 =
    apply_middlewares
      handler
      ~not_allowed_handler:(not_allowed_handler token_ref1)
  in
  let* response = wrapped_handler1 req in
  let status = Opium.Response.status response |> Opium.Status.to_code in
  Alcotest.(check int "Has status 403" 403 status);
  (* Do GET with session to get token *)
  let post_req = Opium.Request.of_urlencoded ~body:[] "/foo" `POST in
  let wrapped_handler2 =
    apply_middlewares
      handler
      ~not_allowed_handler:(not_allowed_handler token_ref2)
  in
  let* response = wrapped_handler2 post_req in
  let status = Opium.Response.status response |> Opium.Status.to_code in
  Alcotest.(check int "Has status 403" 403 status);
  Alcotest.(
    check bool "First Has CSRF token" true (String.length !token_ref1 > 0));
  Alcotest.(
    check bool "Second Has CSRF token" true (String.length !token_ref2 > 0));
  Alcotest.(
    check
      bool
      "Different CSRF tokens"
      false
      (String.equal !token_ref1 !token_ref2));
  Lwt.return ()
;;

let post_request_without_token_fails _ () =
  let post_req = Opium.Request.of_urlencoded ~body:[] "/foo" `POST in
  let allowed = ref false in
  let handler _ =
    allowed := true;
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let wrapped_handler = apply_middlewares handler in
  let* response = wrapped_handler post_req in
  let status = Opium.Response.status response |> Opium.Status.to_code in
  Alcotest.(check int "Has status 403" 403 status);
  Alcotest.(check bool "Is disallowed" false !allowed);
  Lwt.return ()
;;

let post_request_with_foreign_token_fails _ () =
  (* Do GET to get a token *)
  let req = Opium.Request.get "" in
  let token_ref = ref "" in
  let handler req =
    token_ref := Sihl.Web.Csrf.find req;
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let wrapped_handler = apply_middlewares handler in
  let* _ = wrapped_handler req in
  (* New request with new cookie but using generated (foreign) token *)
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

let post_request_with_nonmatching_token_fails _ () =
  (* Do GET to set a token *)
  let req = Opium.Request.get "" in
  let token_ref = ref "" in
  let handler req =
    token_ref := Sihl.Web.Csrf.find req;
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let wrapped_handler = apply_middlewares handler in
  let* response = wrapped_handler req in
  let cookie = response |> Opium.Response.cookies |> List.hd in
  (* New request with same cookie but non-matching token in body *)
  let post_req =
    Opium.Request.of_urlencoded ~body:[ "csrf", [ "garbage" ] ] "/foo" `POST
    |> Opium.Request.add_cookie cookie.Opium.Cookie.value
  in
  let handler _ = Lwt.return @@ Opium.Response.of_plain_text "" in
  let wrapped_handler = apply_middlewares handler in
  let* response = wrapped_handler post_req in
  let status = Opium.Response.status response |> Opium.Status.to_code in
  Alcotest.(check int "Has status 403" 403 status);
  Lwt.return ()
;;

let post_request_with_nonmatching_cookie_fails _ () =
  (* Do GET to set a token *)
  let req = Opium.Request.get "" in
  let token_ref = ref "" in
  let handler req =
    token_ref := Sihl.Web.Csrf.find req;
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let wrapped_handler = apply_middlewares handler in
  let* _ = wrapped_handler req in
  (* New request with same cookie but non-matching token in body *)
  let post_req =
    Opium.Request.of_urlencoded ~body:[ "csrf", [ !token_ref ] ] "/foo" `POST
    |> Opium.Request.add_cookie
         ("__Host-csrf", "ohwZjbBUqb9LVi3BjAb8r1CNskrJQjW")
  in
  let handler _ = Lwt.return @@ Opium.Response.of_plain_text "" in
  let not_allowed_handler req =
    let key, _ = req |> Opium.Request.cookies |> List.hd in
    Alcotest.(check string "Has cookie set" "__Host-csrf" key);
    Lwt.return @@ Opium.Response.of_plain_text "" ~status:`Forbidden
  in
  let wrapped_handler = apply_middlewares handler ~not_allowed_handler in
  let* response = wrapped_handler post_req in
  let status = Opium.Response.status response |> Opium.Status.to_code in
  Alcotest.(check int "Has status 403" 403 status);
  Lwt.return ()
;;

let post_request_with_valid_token_succeeds _ () =
  (* Do GET to set a token *)
  let req = Opium.Request.get "" in
  let token_ref = ref "" in
  let handler req =
    token_ref := Sihl.Web.Csrf.find req;
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let wrapped_handler = apply_middlewares handler in
  let* response = wrapped_handler req in
  let cookie = response |> Opium.Response.cookies |> List.hd in
  (* New request with same cookie and matching token in body *)
  let post_req =
    Opium.Request.of_urlencoded ~body:[ "csrf", [ !token_ref ] ] "/foo" `POST
    |> Opium.Request.add_cookie cookie.Opium.Cookie.value
  in
  let handler _ = Lwt.return @@ Opium.Response.of_plain_text "" in
  let wrapped_handler = apply_middlewares handler in
  let* response = wrapped_handler post_req in
  let status = Opium.Response.status response |> Opium.Status.to_code in
  Alcotest.(check int "Has status 200" 200 status);
  Lwt.return ()
;;

let two_post_requests_succeed _ () =
  (* Do GET to set a token *)
  let req = Opium.Request.get "" in
  let token_ref1 = ref "" in
  let token_ref2 = ref "" in
  let token_ref3 = ref "" in
  let handler tkn req =
    tkn := Sihl.Web.Csrf.find req;
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let wrapped_handler = apply_middlewares @@ handler token_ref1 in
  let* response = wrapped_handler req in
  let status = Opium.Response.status response |> Opium.Status.to_code in
  Alcotest.(check int "Has status 200" 200 status);
  let cookie = response |> Opium.Response.cookies |> List.hd in
  (* New request with same cookie and matching token in body *)
  let post_req =
    Opium.Request.of_urlencoded ~body:[ "csrf", [ !token_ref1 ] ] "/foo" `POST
    |> Opium.Request.add_cookie cookie.Opium.Cookie.value
  in
  let wrapped_handler = apply_middlewares @@ handler token_ref2 in
  let* response = wrapped_handler post_req in
  let status = Opium.Response.status response |> Opium.Status.to_code in
  Alcotest.(check int "Has status 200" 200 status);
  let* response = wrapped_handler req in
  let cookie = response |> Opium.Response.cookies |> List.hd in
  let post_req =
    Opium.Request.of_urlencoded ~body:[ "csrf", [ !token_ref2 ] ] "/foo" `POST
    |> Opium.Request.add_cookie cookie.Opium.Cookie.value
  in
  let wrapped_handler = apply_middlewares @@ handler token_ref3 in
  let* response = wrapped_handler post_req in
  let status = Opium.Response.status response |> Opium.Status.to_code in
  Alcotest.(check int "Has status 200" 200 status);
  Alcotest.(
    check bool "First Has CSRF token" true (String.length !token_ref1 > 0));
  Alcotest.(
    check bool "Second Has CSRF token" true (String.length !token_ref2 > 0));
  Alcotest.(
    check bool "Third Has CSRF token" true (String.length !token_ref3 > 0));
  Alcotest.(
    check
      bool
      "Different CSRF tokens"
      false
      (String.equal !token_ref1 !token_ref2));
  Alcotest.(
    check
      bool
      "Different CSRF tokens"
      false
      (String.equal !token_ref1 !token_ref3));
  Alcotest.(
    check
      bool
      "Different CSRF tokens"
      false
      (String.equal !token_ref2 !token_ref3));
  Lwt.return ()
;;

let suite =
  [ ( "csrf"
    , [ test_case
          "get request yields CSRF token"
          `Quick
          get_request_yields_token
      ; test_case
          "get request without CSRF token succeeds"
          `Quick
          get_request_without_token_succeeds
      ; test_case
          "two get requests yield different CSRF token"
          `Quick
          two_get_requests_yield_different_token
      ; test_case
          "post request yields CSRF token"
          `Quick
          post_request_yields_token
      ; test_case
          "two post requests yield different CSRF token"
          `Quick
          two_post_requests_yield_different_token
      ; test_case
          "post request without CSRF token fails"
          `Quick
          post_request_without_token_fails
      ; test_case
          "post request with foreign CSRF token fails"
          `Quick
          post_request_with_foreign_token_fails
      ; test_case
          "post request with non-matching CSRF token fails"
          `Quick
          post_request_with_nonmatching_token_fails
      ; test_case
          "post request with non-matching CSRF cookie fails"
          `Quick
          post_request_with_nonmatching_cookie_fails
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
