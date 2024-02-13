open Alcotest_lwt
open Sihl.Web

let can_parse_uri_safe _ () =
  let open Csrf.Crypto in
  let with_secret = Sihl.Configuration.read_secret () |> Secret.make in
  let value = Mirage_crypto_rng.generate token_length in
  let enc = Encrypted_token.from_struct ~with_secret value in
  let parsed =
    enc
    |> Encrypted_token.to_uri_safe_string
    |> Encrypted_token.of_uri_safe_string
    |> Option.get
  in
  let open Alcotest in
  check bool "Same decrypted CSRF tokens" true
  @@ Encrypted_token.equal enc parsed;
  Lwt.return ()
;;

let crypto_undo_helper encrypt decrypt =
  let open Csrf.Crypto in
  let with_secret = Sihl.Configuration.read_secret () |> Secret.make in
  let value = Mirage_crypto_rng.generate token_length in
  let dec = encrypt ~with_secret value |> decrypt ~with_secret in
  let open Alcotest in
  check bool "Same decrypted CSRF tokens" true
  @@ Decrypted_token.equal_struct dec value;
  Lwt.return ()
;;

let decrypt_random_undoes_encrypt_random _ () =
  let open Csrf.Crypto in
  crypto_undo_helper
    Encrypted_token.from_struct_random
    Decrypted_token.from_encrypted_random
;;

let decrypt_undoes_encrypt _ () =
  let open Csrf.Crypto in
  crypto_undo_helper Encrypted_token.from_struct Decrypted_token.from_encrypted
;;

let csrf_simulation _ () =
  let open Csrf.Crypto in
  let with_secret = Sihl.Configuration.read_secret () |> Secret.make in
  (* GET request generates value *)
  let value = Mirage_crypto_rng.generate token_length in
  (* Encrypt value for cookie token *)
  let enc = Encrypted_token.from_struct ~with_secret value in
  (* Encrypt value with randomness for body token (take already encrypted cookie
     token because in middleware no access to original value *)
  let req =
    Decrypted_token.from_encrypted_to_encrypted_random ~with_secret enc
    (* Set in request *)
    |> Encrypted_token.to_uri_safe_string
  in
  (* Set in cookie *)
  let ck = enc |> Encrypted_token.to_uri_safe_string in
  (* Token from request body *)
  let received = Encrypted_token.of_uri_safe_string req |> Option.get in
  (* Token from cookie *)
  let stored = ck |> Encrypted_token.of_uri_safe_string |> Option.get in
  let dec_received =
    received |> Decrypted_token.from_encrypted_random ~with_secret
  in
  let dec_stored = stored |> Decrypted_token.from_encrypted ~with_secret in
  let open Alcotest in
  let non_empty tkn =
    check bool "Non empty encrypted token" false (Cstruct.is_empty @@ tkn)
  in
  (* Make sure no token is empty *)
  non_empty @@ Encrypted_token.to_struct received;
  non_empty @@ Encrypted_token.to_struct stored;
  non_empty @@ Cstruct.of_string req;
  non_empty @@ Cstruct.of_string ck;
  check bool "Same decrypted CSRF tokens" true
  @@ Decrypted_token.equal dec_stored dec_received;
  Lwt.return ()
;;

let csrf_name = "_csrf"

let apply_middlewares handler ?not_allowed_handler =
  handler
  |> Rock.Middleware.apply
       (Sihl.Web.Middleware.csrf ?not_allowed_handler ~key:csrf_name ())
;;

let route = "/pizza"

let default_response ?status () =
  Lwt.return @@ Response.of_plain_text ?status "Pizzas"
;;

let get_csrf req = Csrf.find req |> Option.get

let uri_decrypt token =
  let open Csrf.Crypto in
  let with_secret = Sihl.Configuration.read_secret () |> Secret.make in
  token
  |> Encrypted_token.of_uri_safe_string
  |> Option.get
  |> Decrypted_token.from_encrypted_random ~with_secret
;;

let get_request_without_token_succeeds _ () =
  let req = Request.get route in
  let handler _ = default_response () in
  let wrapped_handler = apply_middlewares handler in
  let%lwt response = wrapped_handler req in
  let status = Response.status response |> Opium.Status.to_code in
  let open Alcotest in
  check int "Has status 200" 200 status;
  Lwt.return ()
;;

let get_request_yields_token _ () =
  let req = Request.get route in
  let token = ref "" in
  let handler req =
    token := get_csrf req;
    default_response ()
  in
  let wrapped_handler = apply_middlewares handler in
  let%lwt response = wrapped_handler req in
  (* New encrypted token set in cookie *)
  let value = Sihl.Test.Session.find_resp csrf_name response in
  let open Alcotest in
  check bool "Has CSRF token" true (not @@ CCString.is_empty !token);
  check bool "Has CSRF cookie" true (not @@ CCString.is_empty value);
  Lwt.return ()
;;

let two_get_requests_yield_correct_tokens _ () =
  let req = Request.get route in
  let token1 = ref "" in
  let token2 = ref "" in
  let handler tkn req =
    tkn := get_csrf req;
    default_response ()
  in
  let wrapped_handler1 = apply_middlewares @@ handler token1 in
  let%lwt resp1 = wrapped_handler1 req in
  let cookie = resp1 |> Response.cookie "_session" |> Option.get in
  let status = Response.status resp1 |> Opium.Status.to_code in
  (* Do GET with cookie to maintain session *)
  let get_req = Request.get route |> Request.add_cookie cookie.Cookie.value in
  let wrapped_handler2 = apply_middlewares @@ handler token2 in
  let%lwt resp2 = wrapped_handler2 get_req in
  let find_cookie response = Sihl.Test.Session.find_resp csrf_name response in
  let cookie_token1 = find_cookie resp1 in
  let cookie_token2 = find_cookie resp2 in
  let open Csrf.Crypto in
  let open Alcotest in
  check int "Has status 200" 200 status;
  check bool "First has CSRF token" true (not @@ CCString.is_empty !token1);
  check bool "Second has CSRF token" true (not @@ CCString.is_empty !token2);
  check (neg string) "Different encrypted CSRF tokens" !token1 !token2;
  let decrypt_same str tk1 tk2 =
    check
      bool
      str
      true
      (Decrypted_token.equal (uri_decrypt tk1) (uri_decrypt tk2))
  in
  decrypt_same "Same decrypted CSRF tokens" !token1 !token2;
  check
    string
    "Same encrypted CSRF tokens in cookie"
    cookie_token1
    cookie_token2;
  decrypt_same
    "Same decrypted CSRF tokens in cookie"
    cookie_token1
    cookie_token1;
  Lwt.return ()
;;

let post_request_yields_token _ () =
  let post_req = Request.post route in
  let token = ref "" in
  let not_allowed_handler req =
    token := get_csrf req;
    default_response ~status:`Forbidden ()
  in
  let handler _ = default_response () in
  let wrapped_handler = apply_middlewares handler ~not_allowed_handler in
  let%lwt response = wrapped_handler post_req in
  let status = Response.status response |> Opium.Status.to_code in
  let cookie_token = Sihl.Test.Session.find_resp csrf_name response in
  let open Alcotest in
  check int "Has status 403" 403 status;
  check bool "Has CSRF token" true (not @@ CCString.is_empty !token);
  check bool "Has CSRF cookie" true (not @@ CCString.is_empty cookie_token);
  Lwt.return ()
;;

let two_post_requests_yield_different_token _ () =
  let req = Request.post route in
  let token1 = ref "" in
  let token2 = ref "" in
  let not_allowed_handler tkn req =
    tkn := get_csrf req;
    default_response ()
  in
  let handler _ = default_response () in
  let wrapped_handler1 =
    apply_middlewares handler ~not_allowed_handler:(not_allowed_handler token1)
  in
  let%lwt resp1 = wrapped_handler1 req in
  let wrapped_handler2 =
    apply_middlewares handler ~not_allowed_handler:(not_allowed_handler token2)
  in
  let%lwt resp2 = wrapped_handler2 req in
  let find_cookie response = Sihl.Test.Session.find_resp csrf_name response in
  let cookie_token1 = find_cookie resp1 in
  let cookie_token2 = find_cookie resp2 in
  let open Alcotest in
  check bool "First has CSRF token" true (not @@ CCString.is_empty !token1);
  check bool "Second has CSRF token" true (not @@ CCString.is_empty !token2);
  check
    bool
    "Different decrypted CSRF tokens"
    false
    (Csrf.Crypto.Decrypted_token.equal
       (uri_decrypt !token1)
       (uri_decrypt !token2));
  check
    (neg string)
    "Different encrypted CSRF tokens in cookie"
    cookie_token1
    cookie_token2;
  Lwt.return ()
;;

(* Invalid = missing or not base64 decodable *)
let post_request_both_invalid_tokens_fails _ () =
  let requests =
    CCList.map
      (fun body -> Request.of_urlencoded ~body route `POST)
      [ []; [ csrf_name, [ "garbage" ] ] ]
  in
  let add_cookie =
    [ CCFun.id; Sihl.Test.Session.set_value_req [ csrf_name, "garbage" ] ]
  in
  (* Cartesian product 4 requests, invalid/empty cookie and request *)
  let reqs = CCList.product ( @@ ) add_cookie requests in
  let allowed = ref 0 in
  let handler _ =
    allowed := !allowed + 1;
    default_response ()
  in
  let wrapped_handler = apply_middlewares handler in
  let%lwt responses = Lwt_list.map_s wrapped_handler reqs in
  let statuses =
    CCList.map (fun r -> Opium.Status.to_code @@ Response.status r) responses
  in
  let open Alcotest in
  check bool "Has status 403" true (CCList.for_all (( == ) 403) statuses);
  check int "Is disallowed" 0 !allowed;
  Lwt.return ()
;;

let cookie_invalid_helper reqs =
  (* Do GET to get a token *)
  let req = Request.get route in
  let token = ref "" in
  let allowed = ref 0 in
  let handler1 req =
    token := get_csrf req;
    default_response ()
  in
  let handler2 _ =
    allowed := !allowed + 1;
    default_response ()
  in
  let wrapped_handler = apply_middlewares handler1 in
  let%lwt response = wrapped_handler req in
  (* New requests with new value but using generated (foreign) token *)
  let wrapped_handler = apply_middlewares handler2 in
  let cookie = response |> Response.cookies |> List.hd in
  let%lwt responses = Lwt_list.map_s wrapped_handler @@ reqs (!token, cookie) in
  let statuses =
    CCList.map (fun r -> Opium.Status.to_code @@ Response.status r) responses
  in
  print_endline @@ CCString.concat ", " @@ List.map string_of_int statuses;
  let open Alcotest in
  check bool "Has status 403" true (CCList.for_all (( == ) 403) statuses);
  check int "Is disallowed" 0 !allowed;
  Lwt.return ()
;;

(* Invalid = missing or not base64 decodable *)
let post_request_cookie_invalid_token_fails _ () =
  let reqs (token, _) =
    CCList.map
      (fun add_cookie ->
        Request.of_urlencoded ~body:[ csrf_name, [ token ] ] route `POST
        |> add_cookie)
      [ CCFun.id; Sihl.Test.Session.set_value_req [ csrf_name, "garbage" ] ]
  in
  cookie_invalid_helper reqs
;;

(* Invalid = missing or not base64 decodable *)
let post_request_request_invalid_token_fails _ () =
  let reqs (_, cookie) =
    CCList.map
      (fun body ->
        Request.of_urlencoded ~body route `POST
        |> Request.add_cookie cookie.Cookie.value)
      [ []; [ csrf_name, [ "garbage" ] ] ]
  in
  cookie_invalid_helper reqs
;;

let post_request_with_nonmatching_token_fails _ () =
  let open Csrf.Crypto in
  (* Do GET to get a token *)
  let req = Request.get route in
  let token = ref "" in
  let handler req =
    token := get_csrf req;
    default_response ()
  in
  let wrapped_handler = apply_middlewares handler in
  let%lwt response = wrapped_handler req in
  (* New request with same token in cookie but non-matching token in body *)
  let cookie = response |> Response.cookie "_session" |> Option.get in
  let with_secret = Sihl.Configuration.read_secret () |> Secret.make in
  (* Generate a random encrypted token *)
  let tkn =
    Mirage_crypto_rng.generate token_length
    |> Encrypted_token.from_struct_random ~with_secret
    |> Encrypted_token.to_uri_safe_string
  in
  let post_req =
    Request.of_urlencoded ~body:[ csrf_name, [ tkn ] ] route `POST
    |> Request.add_cookie cookie.Cookie.value
  in
  let handler _ = default_response () in
  let wrapped_handler = apply_middlewares handler in
  let%lwt response = wrapped_handler post_req in
  let status = Response.status response |> Opium.Status.to_code in
  Alcotest.(check int "Has status 403" 403 status);
  Lwt.return ()
;;

let post_request_with_nonmatching_cookie_fails _ () =
  let open Csrf.Crypto in
  (* Do GET to get a token *)
  let req = Request.get route in
  let token = ref "" in
  let handler req =
    token := get_csrf req;
    default_response ()
  in
  let wrapped_handler = apply_middlewares handler in
  let%lwt _ = wrapped_handler req in
  (* Generate a random encrypted token *)
  let with_secret = Sihl.Configuration.read_secret () |> Secret.make in
  let tkn =
    Mirage_crypto_rng.generate token_length
    |> Encrypted_token.from_struct ~with_secret
    |> Encrypted_token.to_uri_safe_string
  in
  (* New request with same token in body but non-matching token in cookie *)
  let post_req =
    Request.of_urlencoded ~body:[ csrf_name, [ !token ] ] route `POST
    |> Sihl.Test.Session.set_value_req [ csrf_name, tkn ]
  in
  let handler _ = default_response () in
  let open Alcotest in
  let not_allowed_handler req =
    let key, _ = req |> Request.cookies |> List.hd in
    check string "Has cookie set" "_session" key;
    default_response () ~status:`Forbidden
  in
  let wrapped_handler = apply_middlewares handler ~not_allowed_handler in
  let%lwt response = wrapped_handler post_req in
  let key = response |> Response.cookies |> List.hd in
  check string "Has cookie set" "_session" @@ fst key.Cookie.value;
  let status = Response.status response |> Opium.Status.to_code in
  check int "Has status 403" 403 status;
  Lwt.return ()
;;

let post_request_with_valid_token_succeeds _ () =
  (* Do GET to get a token *)
  let req = Request.get route in
  let token = ref "" in
  let handler req =
    token := get_csrf req;
    default_response ()
  in
  let wrapped_handler = apply_middlewares handler in
  let%lwt response = wrapped_handler req in
  let cookie = response |> Response.cookies |> List.hd in
  (* New request with same cookie and matching token in body *)
  let post_req =
    Request.of_urlencoded ~body:[ csrf_name, [ !token ] ] route `POST
    |> Request.add_cookie cookie.Cookie.value
  in
  let handler _ = default_response () in
  let wrapped_handler = apply_middlewares handler in
  let%lwt response = wrapped_handler post_req in
  let status = Response.status response |> Opium.Status.to_code in
  Alcotest.(check int "Has status 200" 200 status);
  Lwt.return ()
;;

let two_post_requests_succeed _ () =
  (* Do GET to get a token *)
  let req = Request.get route in
  let token1 = ref "" in
  let token2 = ref "" in
  let token3 = ref "" in
  let handler tkn req =
    tkn := get_csrf req;
    default_response ()
  in
  let wrapped_handler = apply_middlewares @@ handler token1 in
  let%lwt response = wrapped_handler req in
  let cookie = response |> Response.cookies |> List.hd in
  let status1 = Response.status response |> Opium.Status.to_code in
  (* New request with same cookie and matching token in body *)
  let post_req =
    Request.of_urlencoded ~body:[ csrf_name, [ !token1 ] ] route `POST
    |> Request.add_cookie cookie.Cookie.value
  in
  let wrapped_handler = apply_middlewares @@ handler token2 in
  let%lwt response = wrapped_handler post_req in
  let status2 = Response.status response |> Opium.Status.to_code in
  let%lwt response = wrapped_handler req in
  let cookie = response |> Response.cookies |> List.hd in
  let session_key, session_val = "test_key", "test_val" in
  let post_req =
    Request.of_urlencoded ~body:[ csrf_name, [ !token2 ] ] route `POST
    |> Request.add_cookie cookie.Cookie.value
    |> Sihl.Test.Session.set_value_req [ session_key, session_val ]
  in
  let wrapped_handler = apply_middlewares @@ handler token3 in
  let%lwt response = wrapped_handler post_req in
  let status3 = Response.status response |> Opium.Status.to_code in
  let session = Sihl.Test.Session.find_resp session_key response in
  let open Alcotest in
  check string "Session is not overwritten" session_val session;
  CCList.iter (check int "Has status 200" 200) [ status1; status2; status3 ];
  CCList.iter
    (fun tkn -> check bool "Has CSRF token" true (String.length tkn > 0))
    [ !token1; !token2; !token3 ];
  CCList.iter
    (fun (tkn1, tkn2) ->
      check bool "Different CSRF tokens" false (String.equal tkn1 tkn2))
    [ !token1, !token2; !token1, !token3; !token2, !token3 ];
  Lwt.return ()
;;

let stale_duplicated_token_post_request_succeed _ () =
  (* Do GET to get a token *)
  let req = Request.get route in
  let token = ref "" in
  let handler req =
    token := get_csrf req;
    default_response ()
  in
  let wrapped_handler = apply_middlewares handler in
  let%lwt response = wrapped_handler req in
  let old_token = !token in
  let cookie = response |> Response.cookies |> List.hd in
  (* New request with same cookie and matching token in body *)
  let post_req =
    Request.of_urlencoded ~body:[ csrf_name, [ old_token ] ] route `POST
    |> Request.add_cookie cookie.Cookie.value
  in
  (* Do a GET to internally generate a new submittable token *)
  (* This is to make sure an intermediate GET request while a POST uses an old
     token does not interfere with the POST *)
  let%lwt _ = wrapped_handler req in
  let%lwt response1 = wrapped_handler post_req in
  (* Repeat POST request with same token *)
  let%lwt response2 = wrapped_handler post_req in
  let statuses =
    CCList.map
      (fun resp -> Response.status resp |> Opium.Status.to_code)
      [ response1; response2 ]
  in
  let open Alcotest in
  CCList.iter (check int "Has status 200" 200) statuses;
  Lwt.return ()
;;

let suite =
  [ ( "csrf crypto"
    , [ test_case
          "uri safe encoded string can be decoded"
          `Quick
          can_parse_uri_safe
      ; test_case
          "decryption accounting for random undoes random encryption"
          `Quick
          decrypt_random_undoes_encrypt_random
      ; test_case "decryption undoes encryption" `Quick decrypt_undoes_encrypt
      ; test_case "simulate entire CSRF crypto lifecycle" `Quick csrf_simulation
      ] )
  ; ( "csrf"
    , [ test_case
          "get request without CSRF token succeeds"
          `Quick
          get_request_without_token_succeeds
      ; test_case
          "get request yields CSRF token"
          `Quick
          get_request_yields_token
      ; test_case
          "two get requests yield correct CSRF token"
          `Quick
          two_get_requests_yield_correct_tokens
      ; test_case
          "two post requests yield different CSRF token"
          `Quick
          two_post_requests_yield_different_token
      ; test_case
          "post request with invalid CSRF token in cookie and request fails"
          `Quick
          post_request_both_invalid_tokens_fails
      ; test_case
          "post request with invalid CSRF token in cookie fails"
          `Quick
          post_request_cookie_invalid_token_fails
      ; test_case
          "post request with invalid CSRF token in request fails"
          `Quick
          post_request_request_invalid_token_fails
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
      ; test_case
          "post request with stale and duplicated token succeeds"
          `Quick
          stale_duplicated_token_post_request_succeed
      ] )
  ]
;;

let () =
  (* When testing, CSRF check is skipped normally *)
  Unix.putenv "CHECK_CSRF" "true";
  Logs.set_level (Sihl.Log.get_log_level ());
  Logs.set_reporter (Sihl.Log.cli_reporter ());
  Lwt_main.run (Alcotest_lwt.run "csrf" suite)
;;
