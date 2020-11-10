open Lwt.Syntax

let test_require_url_encoded_body _ () =
  let req = Sihl.Http.Request.of_urlencoded ~body:[ "foo", [ "bar" ] ] "" `GET in
  let* value = Sihl.Http.Request.urlencoded "foo" req in
  Alcotest.(check (option string) "parses url encoded body" (Some "bar") value);
  Lwt.return ()
;;

let test_require_tuple_url_encoded_body _ () =
  let req =
    Sihl.Http.Request.of_urlencoded ~body:[ "foo", [ "bar" ]; "fooz", [ "baz" ] ] "" `GET
  in
  let* value1 = Sihl.Http.Request.urlencoded "foo" req |> Lwt.map Option.get in
  let* value2 = Sihl.Http.Request.urlencoded "fooz" req |> Lwt.map Option.get in
  Alcotest.(check @@ string) "parses first value" "bar" value1;
  Alcotest.(check @@ string) "parses second value" "baz" value2;
  Lwt.return ()
;;
