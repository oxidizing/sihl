open Alcotest_lwt
open Lwt.Syntax

let not_touching_flash_without_set_cookie_doesnt_set_cookie _ () =
  let req = Opium.Request.get "/" in
  let* res =
    Rock.Middleware.apply
      (Sihl.Web.Middleware.flash ())
      (fun _ -> Lwt.return @@ Opium.Response.of_plain_text "")
      req
  in
  let cookie = Opium.Response.cookie "_flash" res in
  Alcotest.(check bool "no cookie set" false (Option.is_some cookie));
  Lwt.return ()
;;

let not_touching_flash_doesnt_set_cookie _ () =
  let req = Opium.Request.get "/" |> Opium.Request.add_cookie ("_flash", "") in
  let* res =
    Rock.Middleware.apply
      (Sihl.Web.Middleware.flash ())
      (fun _ -> Lwt.return @@ Opium.Response.of_plain_text "")
      req
  in
  let cookie = Opium.Response.cookie "_flash" res in
  Alcotest.(check bool "no cookie set" false (Option.is_some cookie));
  Lwt.return ()
;;

let flash_is_cleared_after_request _ () =
  let req = Opium.Request.get "/" in
  let* res =
    Rock.Middleware.apply
      (Sihl.Web.Middleware.flash ())
      (fun _ ->
        let res =
          Opium.Response.of_plain_text ""
          |> Sihl.Web.Flash.set_alert (Some "foobar")
        in
        Lwt.return res)
      req
  in
  (* Simulate the browser sending the last Set-Cookie *)
  let cookie = Opium.Response.cookie "_flash" res |> Option.get in
  let cookie_value = cookie.Opium.Cookie.value in
  let req = Opium.Request.get "" in
  let req = Opium.Request.add_cookie cookie_value req in
  let* res =
    Rock.Middleware.apply
      (Sihl.Web.Middleware.flash ())
      (fun req ->
        let alert = Sihl.Web.Flash.find_alert req in
        Alcotest.(check (option string) "has alert" (Some "foobar") alert);
        Lwt.return @@ Opium.Response.of_plain_text "")
      req
  in
  (* Simulate the browser sending the last Set-Cookie *)
  let cookie = Opium.Response.cookie "_flash" res |> Option.get in
  let cookie_value = cookie.Opium.Cookie.value in
  let req = Opium.Request.get "/" in
  let req = Opium.Request.add_cookie cookie_value req in
  let* _ =
    Rock.Middleware.apply
      (Sihl.Web.Middleware.flash ())
      (fun req ->
        let alert = Sihl.Web.Flash.find_alert req in
        Alcotest.(check (option string) "alert was cleared" None alert);
        Lwt.return @@ Opium.Response.of_plain_text "")
      req
  in
  Alcotest.(
    check
      (pair string string)
      "flash is empty"
      (* Default empty flash with default test secret *)
      ("_flash", "")
      cookie_value);
  Lwt.return ()
;;

let set_and_read_flash_message _ () =
  let req = Opium.Request.get "/" in
  let* res =
    Rock.Middleware.apply
      (Sihl.Web.Middleware.flash ())
      (fun req ->
        let alert = Sihl.Web.Flash.find_alert req in
        let notice = Sihl.Web.Flash.find_notice req in
        Alcotest.(check (option string) "has no alert" None alert);
        Alcotest.(check (option string) "has no notice" None notice);
        let res = Opium.Response.of_plain_text "" in
        let res = Sihl.Web.Flash.set_alert (Some "foobar") res in
        Lwt.return res)
      req
  in
  (* Simulate the browser sending the last Set-Cookie *)
  let cookie = Opium.Response.cookie "_flash" res |> Option.get in
  let cookie_value = cookie.Opium.Cookie.value in
  let req = Opium.Request.get "" in
  let req = Opium.Request.add_cookie cookie_value req in
  let* res =
    Rock.Middleware.apply
      (Sihl.Web.Middleware.flash ())
      (fun req ->
        let alert = Sihl.Web.Flash.find_alert req in
        let notice = Sihl.Web.Flash.find_notice req in
        Alcotest.(check (option string) "has alert" (Some "foobar") alert);
        Alcotest.(check (option string) "has no notice" None notice);
        let res = Opium.Response.of_plain_text "" in
        let res = Sihl.Web.Flash.set_alert (Some "nextfoo") res in
        let res = Sihl.Web.Flash.set_custom (Some "hello") res in
        Lwt.return res)
      req
  in
  (* Simulate the browser sending the last Set-Cookie *)
  let cookie = Opium.Response.cookie "_flash" res |> Option.get in
  let cookie_value = cookie.Opium.Cookie.value in
  let req = Opium.Request.get "" |> Opium.Request.add_cookie cookie_value in
  let* response =
    Rock.Middleware.apply
      (Sihl.Web.Middleware.flash ())
      (fun req ->
        let alert = Sihl.Web.Flash.find_alert req in
        let custom = Sihl.Web.Flash.find_custom req in
        Alcotest.(check (option string) "has alert" (Some "nextfoo") alert);
        Alcotest.(check (option string) "has custom" (Some "hello") custom);
        let res = Opium.Response.of_plain_text "" in
        Lwt.return res)
      req
  in
  (* Simulate the browser sending the last Set-Cookie *)
  let cookie = Opium.Response.cookie "_flash" response |> Option.get in
  let cookie_value = cookie.Opium.Cookie.value in
  let req = Opium.Request.get "" |> Opium.Request.add_cookie cookie_value in
  let* _ =
    Rock.Middleware.apply
      (Sihl.Web.Middleware.flash ())
      (fun req ->
        let flash = Sihl.Web.Flash.find_alert req in
        Alcotest.(check (option string) "has no alert" None flash);
        let res = Opium.Response.of_plain_text "" in
        Lwt.return res)
      req
  in
  Lwt.return ()
;;

let suite =
  [ ( "flash"
    , [ test_case
          "not touching flash without set cookie doesn't change cookie"
          `Quick
          not_touching_flash_without_set_cookie_doesnt_set_cookie
      ; test_case
          "not touching flash doesn't change cookie"
          `Quick
          not_touching_flash_doesnt_set_cookie
      ; test_case
          "flash is cleared after request"
          `Quick
          flash_is_cleared_after_request
      ; test_case "set and read flash message" `Quick set_and_read_flash_message
      ] )
  ]
;;

let () =
  Logs.set_level (Sihl.Log.get_log_level ());
  Logs.set_reporter (Sihl.Log.cli_reporter ());
  Lwt_main.run (Alcotest_lwt.run "flash" suite)
;;
