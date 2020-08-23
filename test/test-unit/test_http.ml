open Base
open Sihl.Web
open Lwt.Syntax

let test_require_url_encoded_body _ () =
  let req =
    Sihl.Core.Ctx.empty |> Sihl.Web.Req.create_and_add_to_ctx ~body:"foo=bar"
  in
  let* value = Req.urlencoded req "foo" in
  Alcotest.(check (option string) "parses url encoded body" (Some "bar") value);
  Lwt.return ()

let test_require_tuple_url_encoded_body _ () =
  let req =
    Sihl.Core.Ctx.empty
    |> Sihl.Web.Req.create_and_add_to_ctx ~body:"foo=bar&fooz=baz"
  in
  let* value1, value2 =
    Req.urlencoded2 req "foo" "fooz"
    |> Lwt.map (fun result -> Option.value_exn result)
  in
  Alcotest.(check @@ string) "parses first value" "bar" value1;
  Alcotest.(check @@ string) "parses second value" "baz" value2;
  Lwt.return ()
