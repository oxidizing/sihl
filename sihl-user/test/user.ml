open Lwt.Syntax
open Alcotest_lwt

let equal u1 u2 =
  String.equal
    (Format.asprintf "%a" Sihl_facade.User.pp u1)
    (Format.asprintf "%a" Sihl_facade.User.pp u2)
;;

let alcotest = Alcotest.testable Sihl_facade.User.pp equal

let json_serialization _ () =
  let* () = Sihl_core.Cleaner.clean_all () in
  let* user =
    Sihl_facade.User.create_user
      ~email:"foobar@example.com"
      ~password:"123123123"
      ~username:None
  in
  let user_after =
    user
    |> Sihl_facade.User.to_yojson
    |> Sihl_facade.User.of_yojson
    |> Option.get
  in
  let user = Format.asprintf "%a" Sihl_facade.User.pp user in
  let user_after = Format.asprintf "%a" Sihl_facade.User.pp user_after in
  Alcotest.(check string "is same user" user_after user);
  Lwt.return ()
;;

let update_details _ () =
  let* () = Sihl_core.Cleaner.clean_all () in
  let* user =
    Sihl_facade.User.create_user
      ~email:"foobar@example.com"
      ~password:"123123123"
      ~username:None
  in
  let* updated_user =
    Sihl_facade.User.update_details
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
  let* () = Sihl_core.Cleaner.clean_all () in
  let* user =
    Sihl_facade.User.create_user
      ~email:"foobar@example.com"
      ~password:"123123123"
      ~username:None
  in
  let* _ =
    Sihl_facade.User.update_password
      ~user
      ~old_password:"123123123"
      ~new_password:"12345678"
      ~new_password_confirmation:"12345678"
      ()
    |> Lwt.map Result.get_ok
  in
  let* user =
    Sihl_facade.User.login ~email:"foobar@example.com" ~password:"12345678"
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
  let* () = Sihl_core.Cleaner.clean_all () in
  let* user =
    Sihl_facade.User.create_user
      ~email:"foobar@example.com"
      ~password:"123123123"
      ~username:None
  in
  let* change_result =
    Sihl_facade.User.update_password
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
  let* () = Sihl_core.Cleaner.clean_all () in
  let* user1 =
    Sihl_facade.User.create_user
      ~email:"user1@example.com"
      ~password:"123123123"
      ~username:None
  in
  let* _ =
    Sihl_facade.User.create_user
      ~email:"user2@example.com"
      ~password:"123123123"
      ~username:None
  in
  let* _ =
    Sihl_facade.User.create_user
      ~email:"user3@example.com"
      ~password:"123123123"
      ~username:None
  in
  let* actual_users, meta = Sihl_facade.User.search ~filter:"%user1%" 10 in
  Alcotest.(check int "has correct meta" 3 meta);
  Alcotest.(check (list alcotest) "has one user" actual_users [ user1 ]);
  Lwt.return ()
;;

let suite =
  [ ( "user service"
    , [ test_case "json serialization" `Quick json_serialization
      ; test_case "update details" `Quick update_details
      ; test_case "update password" `Quick update_password
      ; test_case "update password fails" `Quick update_password_fails
      ; test_case "filter users by email" `Quick filter_users_by_email
      ] )
  ]
;;
