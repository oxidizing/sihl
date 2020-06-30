open Sihl.Http

let test_require_url_encoded_body _ () =
  let req =
    Opium.Std.Request.create
      ~body:(Cohttp_lwt.Body.of_string "foo=bar")
      (Cohttp_lwt.Request.make (Uri.of_string "/"))
  in
  let value = Lwt_main.run @@ Req.url_encoded req "foo" in
  Lwt.return @@ Alcotest.(check @@ string) "parses url encoded body" "bar" value

let test_require_tuple_url_encoded_body _ () =
  let req =
    Opium.Std.Request.create
      ~body:(Cohttp_lwt.Body.of_string "foo=bar&fooz=baz")
      (Cohttp_lwt.Request.make (Uri.of_string "/"))
  in
  let value1, value2 = Lwt_main.run @@ Req.url_encoded2 req "foo" "fooz" in
  let () = Alcotest.(check @@ string) "parses first value" "bar" value1 in
  Lwt.return @@ Alcotest.(check @@ string) "parses second value" "baz" value2
