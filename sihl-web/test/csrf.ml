open Alcotest_lwt
open Lwt.Syntax

let xor_empty _ () =
  Alcotest.(
    check
      (option (list char))
      "XORs both empty"
      (Some [])
      (Sihl_web.Csrf.xor [] []));
  Lwt.return ()
;;

let xor_valid _ () =
  let io =
    [ ("a", "8"), "Y"
    ; ("hello", "12345"), "YW_XZ"
    ; ("{}|[]", " !\"#%"), "[\\^xx"
    ]
  in
  List.iter
    (fun ((v1, v2), r) ->
      Alcotest.(
        check
          (option (list char))
          "XORs ASCII"
          (Some (r |> String.to_seq |> List.of_seq))
          (Sihl_web.Csrf.xor
             (v1 |> String.to_seq |> List.of_seq)
             (v2 |> String.to_seq |> List.of_seq))))
    io;
  Lwt.return ()
;;

let xor_length_differs _ () =
  let io = [ "", "1"; "1", ""; "abc", "ab"; "ab", "abc" ] in
  List.iter
    (fun (v, r) ->
      Alcotest.(
        check
          (option (list char))
          "XORs different length"
          None
          (Sihl_web.Csrf.xor
             (v |> String.to_seq |> List.of_seq)
             (r |> String.to_seq |> List.of_seq))))
    io;
  Lwt.return ()
;;

let decrypt_with_salt_empty _ () =
  Alcotest.(
    check
      (option (list char))
      "Decrypts empty"
      (Some [])
      (Sihl_web.Csrf.decrypt_with_salt ~salted_cipher:[] ~salt_length:0));
  Lwt.return ()
;;

let decrypt_with_salt_valid _ () =
  let io =
    [ ("a", "8"), "Y"
    ; ("hello", "12345"), "YW_XZ"
    ; ("{}|[]", " !\"#%"), "[\\^xx"
    ]
  in
  List.iter
    (fun ((v1, v2), r) ->
      Alcotest.(
        check
          (option (list char))
          "Decrypts valid"
          (Some (v2 |> String.to_seq |> List.of_seq))
          (Sihl_web.Csrf.decrypt_with_salt
             ~salted_cipher:(v1 ^ r |> String.to_seq |> List.of_seq)
             ~salt_length:(List.length (r |> String.to_seq |> List.of_seq)))))
    io;
  Lwt.return ()
;;

let decrypt_with_salt_length_differs _ () =
  let io = [ "", "1"; "1", ""; "abcde", "ab"; "ab", "abcde" ] in
  List.iter
    (fun (v, r) ->
      Alcotest.(
        check
          (option (list char))
          "Decrypts different length"
          None
          (Sihl_web.Csrf.decrypt_with_salt
             ~salted_cipher:(r |> String.to_seq |> List.of_seq)
             ~salt_length:(List.length (v |> String.to_seq |> List.of_seq)))))
    io;
  Lwt.return ()
;;

let get_secret tk =
  tk
  |> Base64.decode ~alphabet:Base64.uri_safe_alphabet
  |> Result.get_ok
  |> String.to_seq
  |> List.of_seq
  |> fun tk ->
  Sihl_web.Csrf.decrypt_with_salt
    ~salted_cipher:tk
    ~salt_length:(List.length tk / 2)
  |> Option.get
  |> List.to_seq
  |> String.of_seq
;;

let apply_middlewares handler =
  handler
  |> Rock.Middleware.apply (Sihl_web.Csrf.middleware ())
  |> Rock.Middleware.apply Sihl_web.Form.middleware
  |> Rock.Middleware.apply (Sihl_web.Session.middleware ())
;;

let get_request_yields_token _ () =
  let* () = Sihl_core.Cleaner.clean_all () in
  let req = Opium.Request.get "" in
  let handler req =
    let token_value = Sihl_web.Csrf.find req in
    Alcotest.(check bool "Has CSRF token" true (String.length token_value > 0));
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let wrapped_handler = apply_middlewares handler in
  let* _ = wrapped_handler req in
  Lwt.return ()
;;

let get_request_without_token_succeeds _ () =
  let* () = Sihl_core.Cleaner.clean_all () in
  let req = Opium.Request.get "" in
  let handler _ = Lwt.return @@ Opium.Response.of_plain_text "" in
  let wrapped_handler = apply_middlewares handler in
  let* response = wrapped_handler req in
  let status = Opium.Response.status response |> Opium.Status.to_code in
  Alcotest.(check int "Has status 200" 200 status);
  Lwt.return ()
;;

let two_get_requests_yield_same_token _ () =
  let* () = Sihl_core.Cleaner.clean_all () in
  (* Do GET to set a token *)
  let req = Opium.Request.get "" in
  let token_ref1 = ref "" in
  let token_ref2 = ref "" in
  let handler tkn req =
    tkn := Sihl_web.Csrf.find req;
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let wrapped_handler1 = apply_middlewares (handler token_ref1) in
  let* response = wrapped_handler1 req in
  let cookie = response |> Opium.Response.cookies |> List.hd in
  let status = Opium.Response.status response |> Opium.Status.to_code in
  Alcotest.(check int "Has status 200" 200 status);
  (* Do GET with session to get token *)
  let get_req =
    Opium.Request.get "/foo"
    |> Opium.Request.add_cookie cookie.Opium.Cookie.value
  in
  let wrapped_handler2 = apply_middlewares (handler token_ref2) in
  let* _ = wrapped_handler2 get_req in
  Alcotest.(
    check
      string
      "Same CSRF secret"
      (get_secret !token_ref1)
      (get_secret !token_ref2));
  Lwt.return ()
;;

let post_request_yields_token _ () =
  let* () = Sihl_core.Cleaner.clean_all () in
  let post_req = Opium.Request.of_urlencoded ~body:[] "/foo" `POST in
  let handler req =
    let token_value = Sihl_web.Csrf.find req in
    Alcotest.(
      check bool "Has CSRF token" true (not @@ String.equal "" token_value));
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let wrapped_handler = apply_middlewares handler in
  let* _ = wrapped_handler post_req in
  Lwt.return ()
;;

let post_request_without_token_fails _ () =
  let* () = Sihl_core.Cleaner.clean_all () in
  let post_req = Opium.Request.of_urlencoded ~body:[] "/foo" `POST in
  let handler _ = Lwt.return @@ Opium.Response.of_plain_text "" in
  let wrapped_handler = apply_middlewares handler in
  let* response = wrapped_handler post_req in
  let status = Opium.Response.status response |> Opium.Status.to_code in
  Alcotest.(check int "Has status 403" 403 status);
  Lwt.return ()
;;

let post_request_with_invalid_b64_token_fails _ () =
  let* () = Sihl_core.Cleaner.clean_all () in
  let post_req =
    Opium.Request.of_urlencoded
      ~body:[ "csrf", [ "invalid_token" ] ]
      "/foo"
      `POST
  in
  let handler _ = Lwt.return @@ Opium.Response.of_plain_text "" in
  let wrapped_handler = apply_middlewares handler in
  Lwt.catch
    (fun () -> wrapped_handler post_req |> Lwt.map ignore)
    (function
      | Sihl_web.Csrf.Crypto_failed txt ->
        Alcotest.(
          check string "Raises" "Failed to decode CSRF token. Wrong padding" txt);
        Lwt.return ()
      | exn -> Lwt.fail exn)
;;

let post_request_with_invalid_token_fails _ () =
  let post_req =
    Opium.Request.of_urlencoded ~body:[ "csrf", [ "aGVsbG8=" ] ] "/foo" `POST
  in
  let* () = Sihl_core.Cleaner.clean_all () in
  let handler _ = Lwt.return @@ Opium.Response.of_plain_text "" in
  let wrapped_handler = apply_middlewares handler in
  Lwt.catch
    (fun () -> wrapped_handler post_req |> Lwt.map ignore)
    (function
      | Sihl_web.Csrf.Crypto_failed txt ->
        Alcotest.(check string "Raises" "Failed to decrypt CSRF token" txt);
        Lwt.return ()
      | exn -> Lwt.fail exn)
;;

let post_request_with_nonmatching_token_fails _ () =
  (* Do GET to set a token *)
  let req = Opium.Request.get "" in
  let* () = Sihl_core.Cleaner.clean_all () in
  let token_ref = ref "" in
  let handler req =
    token_ref := Sihl_web.Csrf.find req;
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
  let* () = Sihl_core.Cleaner.clean_all () in
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
  let* () = Sihl_core.Cleaner.clean_all () in
  let token_ref1 = ref "" in
  let token_ref2 = ref "" in
  let handler tkn req =
    tkn := Sihl_web.Csrf.find req;
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
  Alcotest.(
    check bool "Has changed token" false (String.equal !token_ref1 !token_ref2));
  Lwt.return ()
;;

let two_post_requests_succeed _ () =
  (* Do GET to set a token *)
  let req = Opium.Request.get "" in
  let* () = Sihl_core.Cleaner.clean_all () in
  let token_ref1 = ref "" in
  let token_ref2 = ref "" in
  let token_ref3 = ref "" in
  let handler tkn req =
    tkn := Sihl_web.Csrf.find req;
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
  (* Do second POST *)
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
  Alcotest.(
    check bool "Has changed token" false (String.equal !token_ref2 !token_ref3));
  Lwt.return ()
;;

let suite =
  [ ( "encryption"
    , [ test_case "xor empty" `Quick xor_empty
      ; test_case "xor valid" `Quick xor_valid
      ; test_case "xor length differs" `Quick xor_length_differs
      ; test_case "decrypt with salt empty" `Quick decrypt_with_salt_empty
      ; test_case "decrypt with salt valid" `Quick decrypt_with_salt_valid
      ; test_case
          "decrypt with salt length differs"
          `Quick
          decrypt_with_salt_length_differs
      ] )
  ; ( "csrf"
    , [ test_case
          "get request yields CSRF token"
          `Quick
          get_request_yields_token
      ; test_case
          "two get requests yield same CSRF token"
          `Quick
          two_get_requests_yield_same_token
      ; test_case
          "get request without CSRF token succeeds"
          `Quick
          get_request_without_token_succeeds
      ; test_case
          "post request yields CSRF token"
          `Quick
          post_request_yields_token
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
