open Lwt.Syntax
open Alcotest_lwt

let create_and_read_session _ () =
  let* () = Sihl_core.Cleaner.clean_all () in
  let* session = Sihl_facade.Session.create [ "foo", "bar"; "fooz", "baz" ] in
  let* value = Sihl_facade.Session.find_value session "foo" in
  Alcotest.(check (option string) "has value" (Some "bar") value);
  let* value = Sihl_facade.Session.find_value session "fooz" in
  Alcotest.(check (option string) "has value" (Some "baz") value);
  Lwt.return ()
;;

let update_session _ () =
  let* () = Sihl_core.Cleaner.clean_all () in
  let* session = Sihl_facade.Session.create [ "foo", "bar"; "fooz", "baz" ] in
  let* value = Sihl_facade.Session.find_value session "foo" in
  Alcotest.(check (option string) "has value" (Some "bar") value);
  let* () =
    Sihl_facade.Session.set_value session ~k:"foo" ~v:(Some "updated")
  in
  let* value = Sihl_facade.Session.find_value session "foo" in
  Alcotest.(check (option string) "has value" (Some "updated") value);
  let* () = Sihl_facade.Session.set_value session ~k:"foo" ~v:None in
  let* value = Sihl_facade.Session.find_value session "foo" in
  Alcotest.(check (option string) "has value" None value);
  Lwt.return ()
;;

let find_all_session _ () =
  let* () = Sihl_core.Cleaner.clean_all () in
  let* _ = Sihl_facade.Session.create [ "foo", "bar"; "fooz", "baz" ] in
  let* _ = Sihl_facade.Session.create [ "other", "value" ] in
  let* sessions = Sihl_facade.Session.find_all () in
  let s1, s2 =
    match sessions with
    | [ s1; s2 ] -> s1, s2
    | _ -> failwith "Unexpected sessions returned"
  in
  let* value = Sihl_facade.Session.find_value s1 "foo" in
  Alcotest.(check (option string) "has value" (Some "bar") value);
  let* value = Sihl_facade.Session.find_value s1 "other" in
  Alcotest.(check (option string) "has value" None value);
  let* value = Sihl_facade.Session.find_value s2 "other" in
  Alcotest.(check (option string) "has value" (Some "value") value);
  Lwt.return ()
;;

let suite =
  [ ( "session"
    , [ test_case "create and read" `Quick create_and_read_session
      ; test_case "update" `Quick update_session
      ; test_case "find all" `Quick find_all_session
      ] )
  ]
;;
