open Alcotest_lwt

let generate_random_id _ () =
  let middleware = Sihl.Web.Middleware.id () in
  let req = Opium.Request.get "/foo/bar" in
  let id_first = ref "" in
  let handler req =
    let id = Sihl.Web.Id.find req |> Option.get in
    id_first := id;
    Alcotest.(check bool "non empty string" true (String.length id > 0));
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let%lwt _ = Rock.Middleware.apply middleware handler req in
  let id_second = ref "" in
  let handler req =
    let id = Sihl.Web.Id.find req |> Option.get in
    id_second := id;
    Alcotest.(check bool "non empty string" true (String.length id > 0));
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let%lwt _ = Rock.Middleware.apply middleware handler req in
  Alcotest.(
    check bool "different ids" false (String.equal !id_first !id_second));
  Lwt.return ()
;;

let use_provided_id _ () =
  let middleware = Sihl.Web.Middleware.id () in
  let req =
    Opium.Request.get "/foo/bar"
    |> Opium.Request.add_header ("X-Request-ID", "randomid123")
  in
  let handler req =
    let id = Sihl.Web.Id.find req |> Option.get in
    Alcotest.(check string "is provided id" "randomid123" id);
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let%lwt _ = Rock.Middleware.apply middleware handler req in
  Lwt.return ()
;;

let suite =
  [ ( "id"
    , [ test_case "generate random id" `Quick generate_random_id
      ; test_case "use provided id" `Quick use_provided_id
      ] )
  ]
;;

let () =
  Logs.set_level (Sihl.Log.get_log_level ());
  Logs.set_reporter (Sihl.Log.cli_reporter ());
  Lwt_main.run (Alcotest_lwt.run "id" suite)
;;
