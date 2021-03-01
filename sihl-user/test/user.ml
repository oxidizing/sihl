open Lwt.Syntax
open Alcotest_lwt

let equal u1 u2 =
  String.equal
    (Format.asprintf "%a" Sihl_user.pp u1)
    (Format.asprintf "%a" Sihl_user.pp u2)
;;

let alcotest = Alcotest.testable Sihl_user.pp equal

let validate_valid_password _ () =
  let password = "CD&*BA8txf3mRuGF" in
  let actual =
    Sihl_user.validate_new_password
      ~password
      ~password_confirmation:password
      ~password_policy:Sihl_user.default_password_policy
  in
  Alcotest.(check (result unit string) "is valid" (Ok ()) actual);
  Lwt.return ()
;;

let validate_invalid_password _ () =
  let password = "123" in
  let actual =
    Sihl_user.validate_new_password
      ~password
      ~password_confirmation:password
      ~password_policy:Sihl_user.default_password_policy
  in
  Alcotest.(
    check
      (result unit string)
      "is invalid"
      (Error "Password has to contain at least 8 characters")
      actual);
  Lwt.return ()
;;

module Make (UserService : Sihl.Contract.User.Sig) = struct
  let json_serialization _ () =
    let* () = Sihl.Cleaner.clean_all () in
    let* user =
      UserService.create_user
        ~email:"foobar@example.com"
        ~password:"123123123"
        ~username:None
    in
    let user_after =
      user |> Sihl_user.to_yojson |> Sihl_user.of_yojson |> Option.get
    in
    let user = Format.asprintf "%a" Sihl_user.pp user in
    let user_after = Format.asprintf "%a" Sihl_user.pp user_after in
    Alcotest.(check string "is same user" user_after user);
    Lwt.return ()
  ;;

  let update_details _ () =
    let* () = Sihl.Cleaner.clean_all () in
    let* user =
      UserService.create_user
        ~email:"foobar@example.com"
        ~password:"123123123"
        ~username:None
    in
    let* updated_user =
      UserService.update_details
        ~user
        ~email:"new@example.com"
        ~username:(Some "foo")
    in
    let actual_email = updated_user.email in
    let actual_username = updated_user.username in
    Alcotest.(check string "Has updated email" "new@example.com" actual_email);
    Alcotest.(
      check (option string) "Has updated username" (Some "foo") actual_username);
    Lwt.return ()
  ;;

  let update_password _ () =
    let* () = Sihl.Cleaner.clean_all () in
    let* user =
      UserService.create_user
        ~email:"foobar@example.com"
        ~password:"123123123"
        ~username:None
    in
    let* _ =
      UserService.update_password
        ~user
        ~old_password:"123123123"
        ~new_password:"12345678"
        ~new_password_confirmation:"12345678"
        ()
      |> Lwt.map Result.get_ok
    in
    let* user =
      UserService.login ~email:"foobar@example.com" ~password:"12345678"
      |> Lwt.map Result.get_ok
    in
    let actual_email = user.email in
    Alcotest.(
      check
        string
        "Can login with updated password"
        "foobar@example.com"
        actual_email);
    Lwt.return ()
  ;;

  let update_password_fails _ () =
    let* () = Sihl.Cleaner.clean_all () in
    let* user =
      UserService.create_user
        ~email:"foobar@example.com"
        ~password:"123123123"
        ~username:None
    in
    let* change_result =
      UserService.update_password
        ~user
        ~old_password:"wrong_old_password"
        ~new_password:"12345678"
        ~new_password_confirmation:"12345678"
        ()
    in
    Alcotest.(
      check
        (result alcotest string)
        "Can login with updated password"
        (Error "Invalid current password provided")
        change_result);
    Lwt.return ()
  ;;

  let filter_users_by_email _ () =
    let* () = Sihl.Cleaner.clean_all () in
    let* user1 =
      UserService.create_user
        ~email:"user1@example.com"
        ~password:"123123123"
        ~username:None
    in
    let* _ =
      UserService.create_user
        ~email:"user2@example.com"
        ~password:"123123123"
        ~username:None
    in
    let* _ =
      UserService.create_user
        ~email:"user3@example.com"
        ~password:"123123123"
        ~username:None
    in
    let* actual_users, meta = UserService.search ~filter:"%user1%" 10 in
    Alcotest.(check int "has correct meta" 3 meta);
    Alcotest.(check (list alcotest) "has one user" actual_users [ user1 ]);
    Lwt.return ()
  ;;

  let suite =
    [ ( "user service"
      , [ test_case "validate valid password" `Quick validate_valid_password
        ; test_case "validate invalid password" `Quick validate_invalid_password
        ; test_case "json serialization" `Quick json_serialization
        ; test_case "update details" `Quick update_details
        ; test_case "update password" `Quick update_password
        ; test_case "update password fails" `Quick update_password_fails
        ; test_case "filter users by email" `Quick filter_users_by_email
        ] )
    ]
  ;;
end
