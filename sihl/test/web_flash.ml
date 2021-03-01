open Alcotest_lwt
open Lwt.Syntax

let set_and_read_flash_message _ () =
  let req = Opium.Request.get "" in
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
  (* we need to simulate the browser sending back the cookie *)
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
  let cookie = Opium.Response.cookie "_flash" res |> Option.get in
  let cookie_value = cookie.Opium.Cookie.value in
  let req = Opium.Request.get "" in
  let req = Opium.Request.add_cookie cookie_value req in
  let* _ =
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
  let req = Opium.Request.get "" in
  let* _ =
    Rock.Middleware.apply
      (Sihl.Web.Middleware.flash ())
      (fun req ->
        let flash = Sihl.Web.Flash.find_alert req in
        Alcotest.(check (option string) "has no flash content" None flash);
        let res = Opium.Response.of_plain_text "" in
        Lwt.return res)
      req
  in
  Lwt.return ()
;;

let remove_flash_message _ () =
  let req = Opium.Request.get "" in
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
  (* we need to simulate the browser sending back the cookie *)
  let cookie = Opium.Response.cookie "_flash" res |> Option.get in
  let cookie_value = cookie.Opium.Cookie.value in
  let req = Opium.Request.get "" in
  let req = Opium.Request.add_cookie cookie_value req in
  let* res =
    Rock.Middleware.apply
      (Sihl.Web.Middleware.flash ())
      (fun _ ->
        let res = Opium.Response.of_plain_text "" in
        let res = Sihl.Web.Flash.set_alert None res in
        let res = Sihl.Web.Flash.set_custom (Some "hello") res in
        Lwt.return res)
      req
  in
  let cookie = Opium.Response.cookie "_flash" res |> Option.get in
  let cookie_value = cookie.Opium.Cookie.value in
  let req = Opium.Request.get "" in
  let req = Opium.Request.add_cookie cookie_value req in
  let* _ =
    Rock.Middleware.apply
      (Sihl.Web.Middleware.flash ())
      (fun req ->
        let alert = Sihl.Web.Flash.find_alert req in
        let custom = Sihl.Web.Flash.find_custom req in
        Alcotest.(check (option string) "has no alert" None alert);
        Alcotest.(check (option string) "has custom" (Some "hello") custom);
        let res = Opium.Response.of_plain_text "" in
        Lwt.return res)
      req
  in
  let req = Opium.Request.get "" in
  let* _ =
    Rock.Middleware.apply
      (Sihl.Web.Middleware.flash ())
      (fun req ->
        let flash = Sihl.Web.Flash.find_alert req in
        Alcotest.(check (option string) "has no flash content" None flash);
        let res = Opium.Response.of_plain_text "" in
        Lwt.return res)
      req
  in
  Lwt.return ()
;;

let suite =
  [ ( "flash"
    , [ test_case "set and read flash message" `Quick set_and_read_flash_message
      ; test_case "remove flash message" `Quick remove_flash_message
      ] )
  ]
;;

let () =
  Logs.set_level (Sihl.Log.get_log_level ());
  Logs.set_reporter (Sihl.Log.cli_reporter ());
  Lwt_main.run (Alcotest_lwt.run "flash" suite)
;;
