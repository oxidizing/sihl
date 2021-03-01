open Lwt.Syntax
open Alcotest_lwt

let externalize_link _ () =
  let actual = Sihl.Web.Http.externalize_path ~prefix:"prefix" "foo/bar" in
  Alcotest.(check @@ string) "prefixes path" "prefix/foo/bar" actual;
  let actual = Sihl.Web.Http.externalize_path ~prefix:"prefix" "foo/bar/" in
  Alcotest.(check @@ string) "preserve trailing" "prefix/foo/bar/" actual;
  let actual = Sihl.Web.Http.externalize_path ~prefix:"prefix" "/foo/bar/" in
  Alcotest.(check @@ string) "no duplicate slash" "prefix/foo/bar/" actual;
  Lwt.return ()
;;

let prefix_route _ () =
  let route =
    Sihl.Web.Http.get "/users" (fun _ ->
        Lwt.return (Opium.Response.of_plain_text ""))
  in
  let _, prefixed_path, _ = Sihl.Web.Http.prefix "/admin" route in
  Alcotest.(check string "prefix" "/admin/users" prefixed_path);
  Lwt.return ()
;;

let prefix_route_trailing_slash_prefix _ () =
  let route =
    Sihl.Web.Http.get "/users" (fun _ ->
        Lwt.return (Opium.Response.of_plain_text ""))
  in
  let _, prefixed_path, _ = Sihl.Web.Http.prefix "/admin/" route in
  Alcotest.(check string "prefix" "/admin/users" prefixed_path);
  Lwt.return ()
;;

let prefix_route_trailing_slash _ () =
  let route =
    Sihl.Web.Http.get "/users/" (fun _ ->
        Lwt.return (Opium.Response.of_plain_text ""))
  in
  let _, prefixed_path, _ = Sihl.Web.Http.prefix "/admin" route in
  Alcotest.(check string "prefix" "/admin/users/" prefixed_path);
  Lwt.return ()
;;

let router_prefix _ () =
  let open Sihl.Web.Http in
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
    Sihl.Web.Http.get "/users" (fun _ ->
        Lwt.return (Opium.Response.of_plain_text "many users"))
  in
  let route2 =
    Sihl.Web.Http.get "/users/:id" (fun _ ->
        Lwt.return (Opium.Response.of_plain_text "one user"))
  in
  let router =
    Sihl.Web.Http.router
      ~scope:"/api"
      [ route1; route2 ]
      ~middlewares:[ middleware1; middleware2 ]
  in
  let _, _, handler = Sihl.Web.Http.router_to_routes router |> List.hd in
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
  let route1 = Sihl.Web.Http.get "/some/path" handler1 in
  let route2 = Sihl.Web.Http.get "/**" handler2 in
  let router =
    Sihl.Web.Http.router ~scope:"/scope" ~middlewares:[] [ route1; route2 ]
  in
  let _ = Sihl.Web.Http.register ~routers:[ router ] () in
  let* () = Sihl.Web.Http.start () in
  let* _ =
    Cohttp_lwt_unix.Client.get
      (Uri.of_string "http://localhost:3000/scope/some/path")
  in
  Alcotest.(check bool "was called" true !was_called1);
  Alcotest.(check bool "was not called" false !was_called2);
  Sihl.Web.Http.stop ()
;;

let global_middleware_before_router _ () =
  let was_called = ref false in
  let filter _ _ =
    was_called := true;
    Lwt.return @@ Opium.Response.of_plain_text "all good!"
  in
  let middleware = Rock.Middleware.create ~name:"test" ~filter in
  let _ = Sihl.Web.Http.register ~middlewares:[ middleware ] () in
  let* () = Sihl.Web.Http.start () in
  let* resp, _ =
    Cohttp_lwt_unix.Client.get (Uri.of_string "http://localhost:3000")
  in
  let status = resp |> Cohttp.Response.status |> Cohttp.Code.code_of_status in
  Alcotest.(check int "matched scope without route" 200 status);
  Alcotest.(check bool "middleware was called" true !was_called);
  Sihl.Web.Http.stop ()
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
      ; test_case
          "global middleware before router"
          `Quick
          global_middleware_before_router
      ] )
  ]
;;

let () =
  Logs.set_level (Sihl.Log.get_log_level ());
  Logs.set_reporter (Sihl.Log.cli_reporter ());
  Lwt_main.run (Alcotest_lwt.run "opium" suite)
;;
