open Lwt.Syntax
open Alcotest_lwt

let externalize_link _ () =
  let actual = Sihl_web.Http.externalize_path ~prefix:"prefix" "foo/bar" in
  Alcotest.(check @@ string) "prefixes path" "prefix/foo/bar" actual;
  let actual = Sihl_web.Http.externalize_path ~prefix:"prefix" "foo/bar/" in
  Alcotest.(check @@ string) "preserve trailing" "prefix/foo/bar/" actual;
  let actual = Sihl_web.Http.externalize_path ~prefix:"prefix" "/foo/bar/" in
  Alcotest.(check @@ string) "no duplicate slash" "prefix/foo/bar/" actual;
  Lwt.return ()
;;

let prefix_route _ () =
  let route =
    Sihl_web.Http.get "/users" (fun _ ->
        Lwt.return (Opium.Response.of_plain_text ""))
  in
  let _, prefixed_path, _ = Sihl_web.Http.prefix "/admin" route in
  Alcotest.(check string "prefix" "/admin/users" prefixed_path);
  Lwt.return ()
;;

let prefix_route_trailing_slash_prefix _ () =
  let route =
    Sihl_web.Http.get "/users" (fun _ ->
        Lwt.return (Opium.Response.of_plain_text ""))
  in
  let _, prefixed_path, _ = Sihl_web.Http.prefix "/admin/" route in
  Alcotest.(check string "prefix" "/admin/users" prefixed_path);
  Lwt.return ()
;;

let prefix_route_trailing_slash _ () =
  let route =
    Sihl_web.Http.get "/users/" (fun _ ->
        Lwt.return (Opium.Response.of_plain_text ""))
  in
  let _, prefixed_path, _ = Sihl_web.Http.prefix "/admin" route in
  Alcotest.(check string "prefix" "/admin/users/" prefixed_path);
  Lwt.return ()
;;

let router_prefix _ () =
  let open Sihl_web.Http in
  let route1 =
    get "/users" (fun _ ->
        Lwt.return (Opium.Response.of_plain_text "many users"))
  in
  let route2 =
    get "/users/:id" (fun _ ->
        Lwt.return (Opium.Response.of_plain_text "one user"))
  in
  let router = router ~scope:"/api" [ route1; route2 ] in
  let routes = router_to_routes router in
  let path1, path2 =
    match routes with
    | (_, path1, _) :: (_, path2, _) :: _ -> path1, path2
    | _ -> failwith "Not two routes received"
  in
  Alcotest.(check string "path 1" "/api/users" path1);
  Alcotest.(check string "path 2" "/api/users/:id" path2);
  Lwt.return ()
;;

let router_middleware _ () =
  let state = ref [] in
  let middleware1 =
    Rock.Middleware.create
      ~filter:(fun handler req ->
        state := List.concat [ !state; [ 1 ] ];
        handler req)
      ~name:"one"
  in
  let middleware2 =
    Rock.Middleware.create
      ~filter:(fun handler req ->
        state := List.concat [ !state; [ 2 ] ];
        handler req)
      ~name:"two"
  in
  let route1 =
    Sihl_web.Http.get "/users" (fun _ ->
        Lwt.return (Opium.Response.of_plain_text "many users"))
  in
  let route2 =
    Sihl_web.Http.get "/users/:id" (fun _ ->
        Lwt.return (Opium.Response.of_plain_text "one user"))
  in
  let router =
    Sihl_web.Http.router
      ~scope:"/api"
      [ route1; route2 ]
      ~middlewares:[ middleware1; middleware2 ]
  in
  let _, _, handler = Sihl_web.Http.router_to_routes router |> List.hd in
  let req = Opium.Request.make "/foo" `GET in
  let* _ = handler req in
  Alcotest.(check (list int) "correct middleware order" [ 1; 2 ] !state);
  Lwt.return ()
;;

let match_first_route _ () =
  let was_called1 = ref false in
  let was_called2 = ref false in
  let handler1 _ =
    was_called1 := true;
    Lwt.return (Opium.Response.of_plain_text "ello 1")
  in
  let handler2 _ =
    was_called2 := true;
    Lwt.return (Opium.Response.of_plain_text "ello 2")
  in
  let route1 = Sihl_web.Http.get "/some/path" handler1 in
  let route2 = Sihl_web.Http.get "/**" handler2 in
  let router =
    Sihl_web.Http.router ~scope:"/scope" ~middlewares:[] [ route1; route2 ]
  in
  let _ = Sihl_web.Http.register ~routers:[ router ] () in
  let* () = Sihl_web.Http.start () in
  let* _ =
    Cohttp_lwt_unix.Client.get
      (Uri.of_string "http://localhost:3000/scope/some/path")
  in
  Alcotest.(check bool "was called" true !was_called1);
  Alcotest.(check bool "was not called" false !was_called2);
  Lwt.return ()
;;

let suite =
  [ ( "http"
    , [ test_case "match first route" `Quick match_first_route
      ; test_case "prefix path" `Quick externalize_link
      ; test_case "prefix route" `Quick prefix_route
      ; test_case
          "prefix route trailing slash prefix"
          `Quick
          prefix_route_trailing_slash_prefix
      ; test_case
          "prefix route trailing slash"
          `Quick
          prefix_route_trailing_slash
      ; test_case "router prefix" `Quick router_prefix
      ; test_case "router middleware" `Quick router_middleware
      ] )
  ]
;;

let () =
  Logs.set_level (Sihl_core.Log.get_log_level ());
  Logs.set_reporter (Sihl_core.Log.cli_reporter ());
  Lwt_main.run (Alcotest_lwt.run "opium" suite)
;;
