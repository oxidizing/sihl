open Alcotest_lwt

let combine_routers_matches_first_route _ () =
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
  let route1 = Sihl.Web.get "/some/path" handler1 in
  let route2 = Sihl.Web.get "/**" handler2 in
  let router = Sihl.Web.choose ~scope:"/scope" [ route1; route2 ] in
  let service = Sihl.Web.Http.register router in
  let%lwt () = Sihl.Container.Service.start service in
  let%lwt _ =
    Cohttp_lwt_unix.Client.get
      (Uri.of_string "http://localhost:3000/scope/some/path")
  in
  Alcotest.(check bool "was called" true !was_called1);
  Alcotest.(check bool "was not called" false !was_called2);
  Sihl.Container.Service.stop service
;;

let combine_routers_calls_middlewares _ () =
  let root_middleware_was_called = ref false in
  let sub_middleware_was_called = ref false in
  let index_was_called = ref false in
  let foo_was_called = ref false in
  let bar_was_called = ref false in
  let reset_assert_state () =
    root_middleware_was_called := false;
    sub_middleware_was_called := false;
    index_was_called := false;
    foo_was_called := false;
    bar_was_called := false
  in
  reset_assert_state ();
  let middleware_root =
    Rock.Middleware.create ~name:"root" ~filter:(fun hander req ->
        root_middleware_was_called := true;
        hander req)
  in
  let middleware_sub =
    Rock.Middleware.create ~name:"sub" ~filter:(fun hander req ->
        sub_middleware_was_called := true;
        hander req)
  in
  let middleware_foo =
    Rock.Middleware.create ~name:"foo" ~filter:(fun _ _ ->
        Lwt.return @@ Sihl.Web.Response.of_plain_text "foo middleware")
  in
  let middleware_bar =
    Rock.Middleware.create ~name:"bar" ~filter:(fun _ _ ->
        Lwt.return @@ Sihl.Web.Response.of_plain_text "bar middleware")
  in
  let router =
    Sihl.Web.(
      choose
        ~middlewares:[ middleware_root ]
        ~scope:"/root"
        [ choose
            ~middlewares:[ middleware_sub ]
            ~scope:"/sub"
            [ get "/" (fun _ ->
                  index_was_called := true;
                  Lwt.return (Opium.Response.of_plain_text "/"))
            ; get ~middlewares:[ middleware_foo ] "/foo" (fun _ ->
                  foo_was_called := true;
                  Lwt.return (Opium.Response.of_plain_text "/foo"))
            ; get "/fooz" (fun _ ->
                  Lwt.return (Opium.Response.of_plain_text "/fooz"))
            ]
        ; get "/bar" ~middlewares:[ middleware_bar ] (fun _ ->
              bar_was_called := true;
              Lwt.return (Opium.Response.of_plain_text "/bar"))
        ])
  in
  let service = Sihl.Web.Http.register router in
  let status_of_resp resp =
    resp
    |> Lwt.map fst
    |> Lwt.map Cohttp.Response.status
    |> Lwt.map Cohttp.Code.code_of_status
  in
  let%lwt () = Sihl.Container.Service.start service in
  reset_assert_state ();
  let%lwt status =
    Cohttp_lwt_unix.Client.get (Uri.of_string "http://localhost:3000/root")
    |> status_of_resp
  in
  Alcotest.(check int "/root not found" 404 status);
  Alcotest.(
    check bool "/root middleware not called" false !root_middleware_was_called);
  reset_assert_state ();
  let%lwt status =
    Cohttp_lwt_unix.Client.get (Uri.of_string "http://localhost:3000/root/")
    |> status_of_resp
  in
  Alcotest.(check int "/root/ not found" 404 status);
  Alcotest.(
    check bool "/root middleware not called" false !root_middleware_was_called);
  reset_assert_state ();
  let%lwt status =
    Cohttp_lwt_unix.Client.get (Uri.of_string "http://localhost:3000/root/sub")
    |> status_of_resp
  in
  Alcotest.(check int "/root/sub not found" 404 status);
  reset_assert_state ();
  let%lwt status =
    Cohttp_lwt_unix.Client.get (Uri.of_string "http://localhost:3000/root/sub/")
    |> status_of_resp
  in
  Alcotest.(check int "/root/sub/ found" 200 status);
  Alcotest.(
    check bool "root middleware called" true !root_middleware_was_called);
  Alcotest.(check bool "sub middleware called" true !sub_middleware_was_called);
  reset_assert_state ();
  let%lwt body =
    Cohttp_lwt_unix.Client.get
      (Uri.of_string "http://localhost:3000/root/sub/foo")
    |> Lwt.map snd
  in
  let%lwt body = Cohttp_lwt.Body.to_string body in
  Alcotest.(check string "foo middleware called" "foo middleware" body);
  Alcotest.(
    check bool "root middleware called" true !root_middleware_was_called);
  Alcotest.(check bool "sub middleware called" true !sub_middleware_was_called);
  reset_assert_state ();
  let%lwt body =
    Cohttp_lwt_unix.Client.get (Uri.of_string "http://localhost:3000/root/bar")
    |> Lwt.map snd
  in
  let%lwt body = Cohttp_lwt.Body.to_string body in
  Alcotest.(check string "bar middleware called" "bar middleware" body);
  Alcotest.(
    check bool "root middleware called" true !root_middleware_was_called);
  Alcotest.(
    check bool "sub middleware not called" false !sub_middleware_was_called);
  Sihl.Container.Service.stop service
;;

let global_middleware_before_router _ () =
  let filter _ _ = Lwt.return @@ Opium.Response.of_plain_text "all good!" in
  let middleware = Rock.Middleware.create ~name:"test" ~filter in
  let router = Sihl.Web.choose ~middlewares:[] ~scope:"/" [] in
  let service = Sihl.Web.Http.register ~middlewares:[ middleware ] router in
  let%lwt () = Sihl.Container.Service.start service in
  let%lwt resp, body =
    Cohttp_lwt_unix.Client.get
      (Uri.of_string "http://localhost:3000/non/existing")
  in
  let status = resp |> Cohttp.Response.status |> Cohttp.Code.code_of_status in
  let%lwt body = Cohttp_lwt.Body.to_string body in
  Alcotest.(check int "matched without route" 200 status);
  Alcotest.(check string "responds" "all good!" body);
  Sihl.Container.Service.stop service
;;

let suite =
  [ ( "http"
    , [ test_case
          "combine routers matches first route"
          `Quick
          combine_routers_matches_first_route
      ; test_case
          "combine routers calls middlewares"
          `Quick
          combine_routers_calls_middlewares
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
  Lwt_main.run (Alcotest_lwt.run "http" suite)
;;
