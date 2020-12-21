open Lwt.Syntax
open Alcotest_lwt

let authenticate_session _ () =
  let* () = Sihl_core.Cleaner.clean_all () in
  let* session = Sihl_facade.Session.create [] in
  let* user = Sihl_facade.Authn.find_user_in_session_opt session in
  let () =
    match user with
    | Some _ -> Alcotest.fail "has no user per default"
    | None -> ()
  in
  let* user =
    Sihl_facade.User.create_user
      ~email:"hello@example.com"
      ~password:"123123"
      ~username:None
  in
  let* () = Sihl_facade.Authn.authenticate_session user session in
  let* user = Sihl_facade.Authn.find_user_in_session session in
  Alcotest.(check string "has user" "hello@example.com" (Sihl_contract.User.email user));
  Lwt.return ()
;;

let unauthenticate_session _ () =
  let* () = Sihl_core.Cleaner.clean_all () in
  let* session = Sihl_facade.Session.create [] in
  let* user =
    Sihl_facade.User.create_user
      ~email:"hello@example.com"
      ~password:"123123"
      ~username:None
  in
  let* () = Sihl_facade.Authn.authenticate_session user session in
  let* user = Sihl_facade.Authn.find_user_in_session session in
  Alcotest.(check string "has user" "hello@example.com" (Sihl_contract.User.email user));
  let* () = Sihl_facade.Authn.unauthenticate_session session in
  let* user = Sihl_facade.Authn.find_user_in_session_opt session in
  let () =
    match user with
    | Some _ -> Alcotest.fail "user was not logged out"
    | None -> ()
  in
  Lwt.return ()
;;

let suite =
  [ ( "authn"
    , [ test_case "authenticate session" `Quick authenticate_session
      ; test_case "unauthenticate session" `Quick unauthenticate_session
      ] )
  ]
;;
