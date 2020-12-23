open Alcotest_lwt
open Lwt.Syntax

let session_cookie_name = "sihl_session"

let middleware_stack =
  [ Sihl_web.Flash.middleware ()
  ; Sihl_web.Session.middleware ~cookie_name:session_cookie_name ()
  ]
;;

let wrap handler =
  List.fold_left
    (fun handler middleware -> Rock.Middleware.apply middleware handler)
    handler
    middleware_stack
;;

let set_and_read_flash_message _ () =
  let* () = Sihl_core.Cleaner.clean_all () in
  let req = Opium.Request.get "" in
  let* res =
    wrap
      (fun req ->
        let flash = Sihl_web.Flash.find req in
        Alcotest.(check (option string) "has no flash content" None flash);
        let res = Opium.Response.of_plain_text "" in
        let res = Sihl_web.Flash.set (Some "foobar") res in
        Lwt.return res)
      req
  in
  (* we need to simulate the browser sending back the session cookie *)
  let cookie = Opium.Response.cookie session_cookie_name res |> Option.get in
  let cookie_value = cookie.Opium.Cookie.value in
  let req = Opium.Request.get "" in
  let req = Opium.Request.add_cookie cookie_value req in
  let* _ =
    wrap
      (fun req ->
        let flash = Sihl_web.Flash.find req in
        Alcotest.(check (option string) "has flash content" (Some "foobar") flash);
        let res = Opium.Response.of_plain_text "" in
        let res = Sihl_web.Flash.set (Some "nextfoo") res in
        Lwt.return res)
      req
  in
  let* _ =
    wrap
      (fun req ->
        let flash = Sihl_web.Flash.find req in
        Alcotest.(check (option string) "has flash content" (Some "nextfoo") flash);
        let res = Opium.Response.of_plain_text "" in
        Lwt.return res)
      req
  in
  let* _ =
    wrap
      (fun req ->
        let flash = Sihl_web.Flash.find req in
        Alcotest.(check (option string) "has no flash content" None flash);
        let res = Opium.Response.of_plain_text "" in
        Lwt.return res)
      req
  in
  let* sessions = Sihl_facade.Session.find_all () in
  Alcotest.(check int "Has created a session" 1 (List.length sessions));
  Lwt.return ()
;;

let suite =
  [ "flash", [ test_case "set and read flash message" `Quick set_and_read_flash_message ]
  ]
;;
