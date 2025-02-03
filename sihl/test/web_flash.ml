open Alcotest_lwt

let assert_delete_cookie cookie =
  Alcotest.(
    check
      (pair string string)
      "flash is empty"
      ("_flash", "")
      cookie.Opium.Cookie.value);
  match cookie.Opium.Cookie.expires with
  | `Max_age value ->
    if Int64.equal value Int64.zero
    then ()
    else Alcotest.fail "Flash cookie did not expire"
  | _ -> Alcotest.fail "Flash cookie did not expire"
;;

let not_touching_flash_without_set_cookie_doesnt_set_cookie _ () =
  let req = Opium.Request.get "/" in
  let%lwt res =
    Rock.Middleware.apply
      (Sihl.Web.Middleware.flash ())
      (fun _ -> Lwt.return @@ Opium.Response.of_plain_text "")
      req
  in
  let cookie = Opium.Response.cookie "_flash" res in
  Alcotest.(check bool "no cookie set" false (Option.is_some cookie));
  Lwt.return ()
;;

let not_touching_flash_removes_cookie _ () =
  let req =
    Opium.Request.get "/"
    |> Opium.Request.add_cookie
         ("_flash", {|{"alert":null,"notice":null,"custom":[]}|})
  in
  let%lwt res =
    Rock.Middleware.apply
      (Sihl.Web.Middleware.flash ())
      (fun _ -> Lwt.return @@ Opium.Response.of_plain_text "")
      req
  in
  let cookie = Opium.Response.cookie "_flash" res |> Option.get in
  Alcotest.(
    check
      (pair string string)
      "was removed"
      ("_flash", "")
      cookie.Opium.Cookie.value);
  Lwt.return ()
;;

let flash_is_cleared_after_request _ () =
  let req = Opium.Request.get "/" in
  let%lwt res =
    Rock.Middleware.apply
      (Sihl.Web.Middleware.flash ())
      (fun _ ->
         let res =
           Opium.Response.of_plain_text "" |> Sihl.Web.Flash.set_alert "foobar"
         in
         Lwt.return res)
      req
  in
  (* Simulate the browser sending the last Set-Cookie *)
  let cookie = Opium.Response.cookie "_flash" res |> Option.get in
  let cookie_value = cookie.Opium.Cookie.value in
  let req = Opium.Request.get "" in
  let req = Opium.Request.add_cookie cookie_value req in
  let%lwt res =
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
  let%lwt _ =
    Rock.Middleware.apply
      (Sihl.Web.Middleware.flash ())
      (fun req ->
         let alert = Sihl.Web.Flash.find_alert req in
         Alcotest.(check (option string) "alert was cleared" None alert);
         Lwt.return @@ Opium.Response.of_plain_text "")
      req
  in
  assert_delete_cookie cookie;
  Lwt.return ()
;;

let set_and_read_flash_message _ () =
  let req = Opium.Request.get "/" in
  let%lwt res =
    Rock.Middleware.apply
      (Sihl.Web.Middleware.flash ())
      (fun req ->
         let alert = Sihl.Web.Flash.find_alert req in
         let notice = Sihl.Web.Flash.find_notice req in
         Alcotest.(check (option string) "has no alert" None alert);
         Alcotest.(check (option string) "has no notice" None notice);
         let res = Opium.Response.of_plain_text "" in
         let res = Sihl.Web.Flash.set_alert "foobar" res in
         Lwt.return res)
      req
  in
  (* Simulate the browser sending the last Set-Cookie *)
  let cookie = Opium.Response.cookie "_flash" res |> Option.get in
  let cookie_value = cookie.Opium.Cookie.value in
  let req = Opium.Request.get "" in
  let req = Opium.Request.add_cookie cookie_value req in
  let%lwt res =
    Rock.Middleware.apply
      (Sihl.Web.Middleware.flash ())
      (fun req ->
         let alert = Sihl.Web.Flash.find_alert req in
         let notice = Sihl.Web.Flash.find_notice req in
         Alcotest.(check (option string) "has alert" (Some "foobar") alert);
         Alcotest.(check (option string) "has no notice" None notice);
         let res = Opium.Response.of_plain_text "" in
         let res = Sihl.Web.Flash.set_alert "nextfoo" res in
         let res = Sihl.Web.Flash.set [ "hello", "other" ] res in
         Lwt.return res)
      req
  in
  (* Simulate the browser sending the last Set-Cookie *)
  let cookie = Opium.Response.cookie "_flash" res |> Option.get in
  let cookie_value = cookie.Opium.Cookie.value in
  let req = Opium.Request.get "" |> Opium.Request.add_cookie cookie_value in
  let%lwt response =
    Rock.Middleware.apply
      (Sihl.Web.Middleware.flash ())
      (fun req ->
         let alert = Sihl.Web.Flash.find_alert req in
         let custom = Sihl.Web.Flash.find "hello" req in
         Alcotest.(check (option string) "has alert" (Some "nextfoo") alert);
         Alcotest.(check (option string) "has custom" (Some "other") custom);
         let res = Opium.Response.of_plain_text "" in
         Lwt.return res)
      req
  in
  (* Simulate the browser sending the last Set-Cookie *)
  let cookie = Opium.Response.cookie "_flash" response |> Option.get in
  assert_delete_cookie cookie;
  let cookie_value = cookie.Opium.Cookie.value in
  let req = Opium.Request.get "" |> Opium.Request.add_cookie cookie_value in
  let%lwt resp =
    Rock.Middleware.apply
      (Sihl.Web.Middleware.flash ())
      (fun req ->
         let flash = Sihl.Web.Flash.find_alert req in
         Alcotest.(check (option string) "has no alert" None flash);
         let res = Opium.Response.of_plain_text "" in
         Lwt.return res)
      req
  in
  let cookie = Opium.Response.cookie "_flash" resp |> Option.get in
  Alcotest.(
    check
      (pair string string)
      "was removed"
      ("_flash", "")
      cookie.Opium.Cookie.value);
  Lwt.return ()
;;

let suite =
  [ ( "flash"
    , [ test_case
          "not touching flash without set cookie doesn't change cookie"
          `Quick
          not_touching_flash_without_set_cookie_doesnt_set_cookie
      ; test_case
          "not touching flash removes cookie"
          `Quick
          not_touching_flash_removes_cookie
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
