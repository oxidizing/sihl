open Lwt.Syntax
open Alcotest_lwt

let choose_routers_without_path_builds_paths _ () =
  let router =
    Sihl.Web.(
      choose
        [ get "" (fun _ -> Lwt.return @@ Opium.Response.of_plain_text "")
        ; get "foo" (fun _ -> Lwt.return @@ Opium.Response.of_plain_text "")
        ; get "bar" (fun _ -> Lwt.return @@ Opium.Response.of_plain_text "")
        ])
  in
  let paths =
    router |> Sihl.Web.routes_of_router |> List.map (fun (_, path, _) -> path)
  in
  Alcotest.(check (list string) "builds paths" [ "/"; "/foo"; "/bar" ] paths);
  Lwt.return ()
;;

let choose_routers_with_empty_scope_builds_paths _ () =
  let router =
    Sihl.Web.(
      choose
        ~scope:""
        [ get "" (fun _ -> Lwt.return @@ Opium.Response.of_plain_text "")
        ; get "/" (fun _ -> Lwt.return @@ Opium.Response.of_plain_text "")
        ; get "foo" (fun _ -> Lwt.return @@ Opium.Response.of_plain_text "")
        ; get "bar" (fun _ -> Lwt.return @@ Opium.Response.of_plain_text "")
        ])
  in
  let paths =
    router |> Sihl.Web.routes_of_router |> List.map (fun (_, path, _) -> path)
  in
  Alcotest.(
    check (list string) "builds paths" [ "/"; "/"; "/foo"; "/bar" ] paths);
  Lwt.return ()
;;

let choose_routers_with_slash_scope_builds_paths _ () =
  let router =
    Sihl.Web.(
      choose
        ~scope:"/"
        [ get "" (fun _ -> Lwt.return @@ Opium.Response.of_plain_text "")
        ; get "foo" (fun _ -> Lwt.return @@ Opium.Response.of_plain_text "")
        ; get "bar" (fun _ -> Lwt.return @@ Opium.Response.of_plain_text "")
        ])
  in
  let paths =
    router |> Sihl.Web.routes_of_router |> List.map (fun (_, path, _) -> path)
  in
  Alcotest.(check (list string) "builds paths" [ "/"; "/foo"; "/bar" ] paths);
  Lwt.return ()
;;

let choose_routers_builds_paths _ () =
  let router =
    Sihl.Web.(
      choose
        ~scope:"root"
        [ get "" (fun _ -> Lwt.return @@ Opium.Response.of_plain_text "")
        ; get "/" (fun _ -> Lwt.return @@ Opium.Response.of_plain_text "")
        ; get "foo" (fun _ -> Lwt.return @@ Opium.Response.of_plain_text "")
        ; get "bar" (fun _ -> Lwt.return @@ Opium.Response.of_plain_text "")
        ])
  in
  let paths =
    router |> Sihl.Web.routes_of_router |> List.map (fun (_, path, _) -> path)
  in
  Alcotest.(
    check
      (list string)
      "builds paths"
      [ "/root"; "/root/"; "/root/foo"; "/root/bar" ]
      paths);
  Lwt.return ()
;;

let choose_nested_routers_builds_paths _ () =
  let router =
    Sihl.Web.(
      choose
        ~scope:"root"
        [ choose
            ~scope:"sub"
            [ get "" (fun _ -> Lwt.return @@ Opium.Response.of_plain_text "")
            ; get "foo" (fun _ -> Lwt.return @@ Opium.Response.of_plain_text "")
            ; get "fooz" (fun _ ->
                  Lwt.return @@ Opium.Response.of_plain_text "")
            ]
        ; get "bar" (fun _ -> Lwt.return @@ Opium.Response.of_plain_text "bar")
        ])
  in
  let paths =
    router |> Sihl.Web.routes_of_router |> List.map (fun (_, path, _) -> path)
  in
  Alcotest.(
    check
      (list string)
      "builds paths"
      [ "/root/sub"; "/root/sub/foo"; "/root/sub/fooz"; "/root/bar" ]
      paths);
  Lwt.return ()
;;

let externalize_link _ () =
  let actual = Sihl.Web.externalize_path ~prefix:"prefix" "foo/bar" in
  Alcotest.(check string "prefixes path" "prefix/foo/bar" actual);
  let actual = Sihl.Web.externalize_path ~prefix:"prefix" "foo/bar/" in
  Alcotest.(check string "preserve trailing" "prefix/foo/bar/" actual);
  let actual = Sihl.Web.externalize_path ~prefix:"prefix" "/foo/bar/" in
  Alcotest.(check string "no duplicate slash" "prefix/foo/bar/" actual);
  Lwt.return ()
;;

let find_bearer_token _ () =
  let token_value = "tokenvalue123" in
  let token_header = Format.sprintf "Bearer %s" token_value in
  let req =
    Opium.Request.get "/some/path/login"
    |> Opium.Request.add_header ("authorization", token_header)
  in
  let handler req =
    let token = Sihl.Web.Request.bearer_token req in
    Alcotest.(check (option string) "has token" (Some token_value) token);
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let* _ = handler req in
  Lwt.return ()
;;

let find_bearer_token_with_space _ () =
  let token_value = "tokenvalue123 and after space" in
  let token_header = Format.sprintf "Bearer %s" token_value in
  let req =
    Opium.Request.get "/some/path/login"
    |> Opium.Request.add_header ("authorization", token_header)
  in
  let handler req =
    let token = Sihl.Web.Request.bearer_token req in
    Alcotest.(check (option string) "has token" (Some "tokenvalue123") token);
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let* _ = handler req in
  Lwt.return ()
;;

let suite =
  [ ( "router"
    , [ test_case
          "choose routers without path builds paths"
          `Quick
          choose_routers_without_path_builds_paths
      ; test_case
          "choose routers with empty scope builds paths"
          `Quick
          choose_routers_with_empty_scope_builds_paths
      ; test_case
          "choose routers with slash scope builds paths"
          `Quick
          choose_routers_with_slash_scope_builds_paths
      ; test_case
          "choose routers builds paths"
          `Quick
          choose_routers_builds_paths
      ; test_case
          "choose nested routers builds paths"
          `Quick
          choose_nested_routers_builds_paths
      ] )
  ; "path", [ test_case "prefix" `Quick externalize_link ]
  ; ( "bearer token"
    , [ test_case "find bearer token" `Quick find_bearer_token
      ; test_case
          "find bearer token with space"
          `Quick
          find_bearer_token_with_space
      ] )
  ]
;;

let () =
  Logs.set_level (Sihl.Log.get_log_level ());
  Logs.set_reporter (Sihl.Log.cli_reporter ());
  Lwt_main.run (Alcotest_lwt.run "web" suite)
;;
