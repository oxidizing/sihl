open Alcotest_lwt

let no_cookie_set_without_session _ () =
  let req =
    Opium.Request.get ""
    (* default empty session with default test secret *)
    |> Opium.Request.add_cookie ("_session", "{}")
  in
  let handler _ =
    (* We don't set any session values *)
    Opium.Response.of_plain_text "" |> Lwt.return
  in
  let%lwt response = handler req in
  Alcotest.(
    check int "no cookies set" 0 (List.length (Opium.Response.cookies response)));
  Lwt.return ()
;;

let unsigned_session_cookie _ () =
  let req =
    Opium.Request.get ""
    (* default empty session with default test secret *)
    |> Opium.Request.add_cookie ("_session", {|{"foo":"bar"}|})
  in
  let handler req =
    let value = Sihl.Web.Session.find "foo" req in
    Alcotest.(check (option string) "no session" None value);
    Opium.Response.of_plain_text "" |> Lwt.return
  in
  let%lwt _ = handler req in
  Lwt.return ()
;;

let invalid_session_cookie_signature _ () =
  let req =
    Opium.Request.get ""
    (* default empty session with default test secret *)
    |> Opium.Request.add_cookie
         ("_session", {|{"foo":"bar"}.aE75kXj9sbZp6tP7oJLhrp9c/+w=|})
  in
  let handler req =
    let value = Sihl.Web.Session.find "foo" req in
    Alcotest.(check (option string) "no session" None value);
    Opium.Response.of_plain_text "" |> Lwt.return
  in
  let%lwt _ = handler req in
  Lwt.return ()
;;

let invalid_session_cookie_value _ () =
  let req =
    Opium.Request.get ""
    (* default empty session with default test secret *)
    |> Opium.Request.add_cookie
         ("_session", "foobar.AMemANOgnmTyWt8YIGmvZQ9GgZM=")
  in
  let handler req =
    let value = Sihl.Web.Session.find "foo" req in
    Alcotest.(check (option string) "no session" None value);
    Opium.Response.of_plain_text "" |> Lwt.return
  in
  let%lwt _ = handler req in
  Lwt.return ()
;;

let cookie_set _ () =
  let req = Opium.Request.get "" in
  let handler _ =
    let resp = Opium.Response.of_plain_text "" in
    Lwt.return @@ Sihl.Web.Session.set [ "foo", "bar" ] resp
  in
  let%lwt response = handler req in
  let cookie = Opium.Response.cookies response |> List.hd in
  let cookie_value = cookie.Opium.Cookie.value in
  Alcotest.(
    check
      (pair string string)
      "persists session values"
      ("_session", {|{"foo":"bar"}.AMemANOgnmTyWt8YIGmvZQ9GgZM=|})
      cookie_value);
  Lwt.return ()
;;

let session_persisted_across_requests _ () =
  let req = Opium.Request.get "" in
  let handler _ =
    let resp = Opium.Response.of_plain_text "" in
    Lwt.return @@ Sihl.Web.Session.set [ "foo", "bar" ] resp
  in
  let%lwt response = handler req in
  let cookies = Opium.Response.cookies response in
  Alcotest.(
    check int "responds with exactly one cookie" 1 (List.length cookies));
  let cookie = Opium.Response.cookie "_session" response |> Option.get in
  let cookie_value = cookie.Opium.Cookie.value in
  Alcotest.(
    check
      (pair string string)
      "persists session values"
      ("_session", {|{"foo":"bar"}.AMemANOgnmTyWt8YIGmvZQ9GgZM=|})
      cookie_value);
  let req =
    Opium.Request.get "" |> Opium.Request.add_cookie cookie.Opium.Cookie.value
  in
  let handler req =
    let session_value = Sihl.Web.Session.find "foo" req in
    Alcotest.(
      check (option string) "has session value" (Some "bar") session_value);
    let resp =
      Opium.Response.of_plain_text ""
      |> Sihl.Web.Session.set [ "fooz", "other" ]
    in
    Lwt.return resp
  in
  let%lwt response = handler req in
  let cookies = Opium.Response.cookies response in
  Alcotest.(
    check int "responds with exactly one cookie" 1 (List.length cookies));
  let cookie = Opium.Response.cookie "_session" response |> Option.get in
  let cookie_value = cookie.Opium.Cookie.value in
  Alcotest.(
    check
      (pair string string)
      "persists session values"
      ("_session", {|{"fooz":"other"}.r96wRxmM2BrUBv3jOIovTWtu3aU=|})
      cookie_value);
  let req =
    Opium.Request.get "" |> Opium.Request.add_cookie cookie.Opium.Cookie.value
  in
  let handler req =
    Alcotest.(
      check
        (option string)
        "has deleted session value"
        None
        (Sihl.Web.Session.find "foo" req));
    Alcotest.(
      check
        (option string)
        "has set session value"
        (Some "other")
        (Sihl.Web.Session.find "fooz" req));
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let%lwt _ = handler req in
  Lwt.return ()
;;

let fetch_all_kv_pairs _ () =
  let open Sihl.Web in
  let session = [ "foo", "bar"; "baz", "qux"; "foo", "quux" ] in
  let req = Request.get "" |> Sihl.Test.Session.set_value_req session in
  let handler req =
    let all = req |> Session.get_all |> Option.get in
    Alcotest.(
      check
        (list (pair string string))
        "session unchanged, duplicates removed"
        (CCList.tail_opt session |> Option.get)
        all);
    Response.of_plain_text "" |> Lwt.return
  in
  let%lwt _ = handler req in
  Lwt.return ()
;;

let update_value _ () =
  let open Sihl.Web in
  let target1 = "baz", "qux" in
  let target2 = "waldo", "grault" in
  let con = "able" in
  let session = [ "foo", "bar"; target1; "foo", "quux" ] in
  let req = Request.get "" in
  let handler _ =
    Response.of_plain_text ""
    |> Session.set session
    |> Session.update_or_set_value
         ~key:(fst target1)
         (function
           | None -> Alcotest.fail "value should be found"
           | Some v -> Some (con ^ v))
         req
    |> Session.update_or_set_value
         ~key:(fst target2)
         (function
           | None -> Some (snd target2)
           | Some _ -> Alcotest.fail "value should not be found")
         req
    |> Lwt.return
  in
  let%lwt response = handler req in
  Alcotest.(
    check
      (list @@ pair string string)
      "values updated in session"
      [ CCPair.map_snd (( ^ ) con) target1
      ; CCList.last_opt session |> Option.get
      ; target2
      ]
      (Sihl.Test.Session.get_all_resp response |> Option.get));
  Lwt.return ()
;;

let delete_value _ () =
  let open Sihl.Web in
  let target1 = "baz", "qux" in
  let target2 = "waldo", "grault" in
  let session = [ "foo", "bar"; target1; "foo", "quux" ] in
  let req = Request.get "" in
  let handler _ =
    Response.of_plain_text ""
    |> Session.set session
    |> Session.update_or_set_value
         ~key:(fst target1)
         (function
           | None -> Alcotest.fail "value should be found"
           | Some _ -> None)
         req
    |> Session.update_or_set_value
         ~key:(fst target2)
         (function
           | None -> None
           | Some _ -> Alcotest.fail "value should not be found")
         req
    |> Lwt.return
  in
  let%lwt response = handler req in
  Alcotest.(
    check
      (list @@ pair string string)
      "session remains same"
      [ CCList.last_opt session |> Option.get ]
      (Sihl.Test.Session.get_all_resp response |> Option.get));
  Lwt.return ()
;;

let set_value _ () =
  let open Sihl.Web in
  let target1 = "baz", "qux" in
  let target2 = "waldo" in
  let updated = "grault" in
  let session = [ "foo", "bar"; target1; "foo", "quux" ] in
  let req = Request.get "" in
  let handler _ =
    Response.of_plain_text ""
    |> Session.set session
    |> Session.set_value ~key:(fst target1) updated req
    |> Session.set_value ~key:target2 updated req
    |> Lwt.return
  in
  let%lwt response = handler req in
  Alcotest.(
    check
      (list @@ pair string string)
      "values set in session"
      [ CCPair.map_snd (CCFun.const updated) target1
      ; CCList.last_opt session |> Option.get
      ; target2, updated
      ]
      (Sihl.Test.Session.get_all_resp response |> Option.get));
  Lwt.return ()
;;

let suite =
  [ ( "session"
    , [ test_case
          "no cookie set without session"
          `Quick
          no_cookie_set_without_session
      ; test_case "unsigned session cookie" `Quick unsigned_session_cookie
      ; test_case
          "invalid session cookie signature"
          `Quick
          invalid_session_cookie_signature
      ; test_case
          "invalid session cookie value"
          `Quick
          invalid_session_cookie_value
      ; test_case "cookie set" `Quick cookie_set
      ; test_case
          "session persisted across requests"
          `Quick
          session_persisted_across_requests
      ; test_case "fetch all values in session" `Quick fetch_all_kv_pairs
      ; test_case
          "update existing and non-existing value in session"
          `Quick
          update_value
      ; test_case
          "delete existing and non-existing value in session"
          `Quick
          delete_value
      ; test_case "set value in session" `Quick set_value
      ] )
  ]
;;

let () =
  Logs.set_level (Sihl.Log.get_log_level ());
  Logs.set_reporter (Sihl.Log.cli_reporter ());
  Lwt_main.run (Alcotest_lwt.run "session" suite)
;;
