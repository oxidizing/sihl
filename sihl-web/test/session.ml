open Alcotest_lwt
open Lwt.Syntax

let multiple_requests_create_one_session _ () =
  let* () = Sihl_core.Cleaner.clean_all () in
  let middleware = Sihl_web.Middleware.Session.m () in
  let req = Opium.Request.get "" in
  let* res =
    Rock.Middleware.apply
      middleware
      (fun _ -> Lwt.return @@ Opium.Response.of_plain_text "")
      req
  in
  let* sessions = Sihl_facade.Session.find_all () in
  let session_value1 = sessions |> List.hd |> Sihl_contract.Session.key in
  Alcotest.(check int "Has created a session" 1 (List.length sessions));
  let cookie = Opium.Response.cookie "sihl.session" res |> Option.get in
  let cookie_value = cookie.Opium.Cookie.value in
  let* _ =
    Rock.Middleware.apply
      middleware
      (fun _ -> Lwt.return Opium.Response.(of_plain_text ""))
      (Opium.Request.add_cookie cookie_value req)
  in
  let* sessions = Sihl_facade.Session.find_all () in
  let session_value2 = sessions |> List.hd |> Sihl_contract.Session.key in
  Alcotest.(check int "Has created just one session" 1 (List.length sessions));
  Alcotest.(check string "Same session reused" session_value1 session_value2);
  Lwt.return ()
;;

let requests_persist_session_variables _ () =
  let* () = Sihl_core.Cleaner.clean_all () in
  let middleware = Sihl_web.Middleware.Session.m () in
  let req = Opium.Request.get "" in
  let handler req =
    let session = Sihl_web.Middleware.Session.find req in
    let* () = Sihl_facade.Session.set_value session ~k:"foo" ~v:(Some "bar") in
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let* _ = Rock.Middleware.apply middleware handler req in
  let* session = Sihl_facade.Session.find_all () |> Lwt.map List.hd in
  let* value = Sihl_facade.Session.find_value session "foo" in
  Alcotest.(
    check (option string) "Has created session with session value" (Some "bar") value);
  Lwt.return ()
;;

let suite =
  [ ( "session"
    , [ test_case
          "multiple requests create one session"
          `Quick
          multiple_requests_create_one_session
      ; test_case
          "requests persist session variable"
          `Quick
          requests_persist_session_variables
      ] )
  ]
;;
