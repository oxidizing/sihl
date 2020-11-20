open Lwt.Syntax

let test_require_url_encoded_body _ () =
  let req = Sihl_type.Http_request.of_urlencoded ~body:[ "foo", [ "bar" ] ] "" `GET in
  let* value = Sihl_type.Http_request.urlencoded "foo" req in
  Alcotest.(check (option string) "parses url encoded body" (Some "bar") value);
  Lwt.return ()
;;

let test_require_tuple_url_encoded_body _ () =
  let req =
    Sihl_type.Http_request.of_urlencoded
      ~body:[ "foo", [ "bar" ]; "fooz", [ "baz" ] ]
      ""
      `GET
  in
  let* value1 = Sihl_type.Http_request.urlencoded "foo" req |> Lwt.map Option.get in
  let* value2 = Sihl_type.Http_request.urlencoded "fooz" req |> Lwt.map Option.get in
  Alcotest.(check @@ string) "parses first value" "bar" value1;
  Alcotest.(check @@ string) "parses second value" "baz" value2;
  Lwt.return ()
;;

let suite =
  Alcotest_lwt.
    [ ( "http"
      , [ test_case "require url encoded body" `Quick test_require_url_encoded_body
        ; test_case
            "require tuple url encoded body"
            `Quick
            test_require_tuple_url_encoded_body
        ] )
    ]
;;

let () =
  Unix.putenv "SIHL_ENV" "test";
  Lwt_main.run (Alcotest_lwt.run "http" suite)
;;
