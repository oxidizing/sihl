open Lwt.Syntax
open Alcotest_lwt

module Make
    (SessionService : Sihl_contract.Session.Sig)
    (UserService : Sihl_contract.User.Sig)
    (AuthnService : Sihl_contract.Authn.Sig) =
struct
  let authenticate_session _ () =
    let* () = Sihl_persistence.Repository.clean_all () in
    let* session = SessionService.create [] in
    let* user = AuthnService.find_user_in_session_opt session in
    let () =
      match user with
      | Some _ -> Alcotest.fail "has no user per default"
      | None -> ()
    in
    let* user =
      UserService.create_user ~email:"hello@example.com" ~password:"123123" ~username:None
    in
    let* () = AuthnService.authenticate_session user session in
    let* user = AuthnService.find_user_in_session session in
    Alcotest.(check string "has user" "hello@example.com" (Sihl_type.User.email user));
    Lwt.return ()
  ;;

  let unauthenticate_session _ () =
    let* () = Sihl_persistence.Repository.clean_all () in
    let* session = SessionService.create [] in
    let* user =
      UserService.create_user ~email:"hello@example.com" ~password:"123123" ~username:None
    in
    let* () = AuthnService.authenticate_session user session in
    let* user = AuthnService.find_user_in_session session in
    Alcotest.(check string "has user" "hello@example.com" (Sihl_type.User.email user));
    let* () = AuthnService.unauthenticate_session session in
    let* user = AuthnService.find_user_in_session_opt session in
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
end
