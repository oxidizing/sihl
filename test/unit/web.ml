open Lwt.Syntax

let externalize_link _ () =
  let actual = Sihl.Http.Route.externalize_path ~prefix:"prefix" "foo/bar" in
  Alcotest.(check @@ string) "prefixes path" "prefix/foo/bar" actual;
  let actual = Sihl.Http.Route.externalize_path ~prefix:"prefix" "foo/bar/" in
  Alcotest.(check @@ string) "preserve trailing" "prefix/foo/bar/" actual;
  let actual = Sihl.Http.Route.externalize_path ~prefix:"prefix" "/foo/bar/" in
  Alcotest.(check @@ string) "no duplicate slash" "prefix/foo/bar/" actual;
  Lwt.return ()
;;

let prefix_route _ () =
  let route =
    Sihl.Http.Route.get "/users" (fun _ ->
        Lwt.return (Sihl.Http.Response.of_plain_text ""))
  in
  let _, prefixed_path, _ = Sihl.Http.Route.prefix "/admin" route in
  Alcotest.(check string "prefix" "/admin/users" prefixed_path);
  Lwt.return ()
;;

let prefix_route_trailing_slash_prefix _ () =
  let route =
    Sihl.Http.Route.get "/users" (fun _ ->
        Lwt.return (Sihl.Http.Response.of_plain_text ""))
  in
  let _, prefixed_path, _ = Sihl.Http.Route.prefix "/admin/" route in
  Alcotest.(check string "prefix" "/admin/users" prefixed_path);
  Lwt.return ()
;;

let prefix_route_trailing_slash _ () =
  let route =
    Sihl.Http.Route.get "/users/" (fun _ ->
        Lwt.return (Sihl.Http.Response.of_plain_text ""))
  in
  let _, prefixed_path, _ = Sihl.Http.Route.prefix "/admin" route in
  Alcotest.(check string "prefix" "/admin/users/" prefixed_path);
  Lwt.return ()
;;

let router_prefix _ () =
  let open Sihl.Http.Route in
  let route1 =
    get "/users" (fun _ -> Lwt.return (Sihl.Http.Response.of_plain_text "many users"))
  in
  let route2 =
    get "/users/:id" (fun _ -> Lwt.return (Sihl.Http.Response.of_plain_text "one user"))
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
    Sihl.Http.Middleware.create
      ~filter:(fun handler req ->
        state := List.concat [ !state; [ 1 ] ];
        handler req)
      ~name:"one"
  in
  let middleware2 =
    Sihl.Http.Middleware.create
      ~filter:(fun handler req ->
        state := List.concat [ !state; [ 2 ] ];
        handler req)
      ~name:"two"
  in
  let route1 =
    Sihl.Http.Route.get "/users" (fun _ ->
        Lwt.return (Sihl.Http.Response.of_plain_text "many users"))
  in
  let route2 =
    Sihl.Http.Route.get "/users/:id" (fun _ ->
        Lwt.return (Sihl.Http.Response.of_plain_text "one user"))
  in
  let router =
    Sihl.Http.Route.router
      ~scope:"/api"
      [ route1; route2 ]
      ~middlewares:[ middleware1; middleware2 ]
  in
  let _, _, handler = Sihl.Http.Route.router_to_routes router |> List.hd in
  let req = Sihl.Http.Request.make "/foo" `GET in
  let* _ = handler req in
  Alcotest.(check (list int) "correct middleware order" [ 1; 2 ] !state);
  Lwt.return ()
;;
