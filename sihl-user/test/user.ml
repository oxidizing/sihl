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
    let%lwt () = Sihl.Cleaner.clean_all () in
    let%lwt user =
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
    let%lwt () = Sihl.Cleaner.clean_all () in
    let%lwt user =
      UserService.create_user
        ~email:"foobar@example.com"
        ~password:"123123123"
        ~username:None
    in
    let%lwt updated_user =
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
    let%lwt () = Sihl.Cleaner.clean_all () in
    let%lwt user =
      UserService.create_user
        ~email:"foobar@example.com"
        ~password:"123123123"
        ~username:None
    in
    let%lwt _ =
      UserService.update_password
        ~user
        ~old_password:"123123123"
        ~new_password:"12345678"
        ~new_password_confirmation:"12345678"
        ()
      |> Lwt.map Result.get_ok
    in
    let%lwt user =
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
    let%lwt () = Sihl.Cleaner.clean_all () in
    let%lwt user =
      UserService.create_user
        ~email:"foobar@example.com"
        ~password:"123123123"
        ~username:None
    in
    let%lwt change_result =
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

  let filter_users_by_email_returns_single_user _ () =
    let%lwt () = Sihl.Cleaner.clean_all () in
    let%lwt user1 =
      UserService.create_user
        ~email:"user1@example.com"
        ~password:"123123123"
        ~username:None
    in
    let%lwt _ =
      UserService.create_user
        ~email:"user2@example.com"
        ~password:"123123123"
        ~username:None
    in
    let%lwt _ =
      UserService.create_user
        ~email:"user3@example.com"
        ~password:"123123123"
        ~username:None
    in
    let%lwt actual_users, meta =
      UserService.search ~filter:"%user1%" ~limit:10 ()
    in
    Alcotest.(check int "has correct meta" 3 meta);
    Alcotest.(check (list alcotest) "has one user" [ user1 ] actual_users);
    Lwt.return ()
  ;;

  let filter_users_by_email_returns_all_users _ () =
    let%lwt () = Sihl.Cleaner.clean_all () in
    let%lwt user1 =
      UserService.create_user
        ~email:"user1@example.com"
        ~password:"123123123"
        ~username:None
    in
    let%lwt user2 =
      UserService.create_user
        ~email:"user2@example.com"
        ~password:"123123123"
        ~username:None
    in
    let%lwt user3 =
      UserService.create_user
        ~email:"user3@example.com"
        ~password:"123123123"
        ~username:None
    in
    let%lwt actual_users, meta =
      UserService.search ~filter:"%user%" ~limit:10 ()
    in
    Alcotest.(check int "has correct meta" 3 meta);
    Alcotest.(
      check (list alcotest) "has all users" [ user3; user2; user1 ] actual_users);
    let%lwt actual_users, meta =
      UserService.search ~filter:"%user%" ~limit:10 ~offset:2 ()
    in
    Alcotest.(check int "has correct meta" 3 meta);
    Alcotest.(check (list alcotest) "has one user" [ user1 ] actual_users);
    Lwt.return ()
  ;;

  let sort_users _ () =
    let%lwt () = Sihl.Cleaner.clean_all () in
    let%lwt user1 =
      UserService.create_user
        ~email:"user1@example.com"
        ~password:"123123123"
        ~username:None
    in
    let%lwt user2 =
      UserService.create_user
        ~email:"user2@example.com"
        ~password:"123123123"
        ~username:None
    in
    let%lwt user3 =
      UserService.create_user
        ~email:"user3@example.com"
        ~password:"123123123"
        ~username:None
    in
    let%lwt actual_users, meta =
      UserService.search ~sort:`Desc ~filter:"%user%" ~limit:10 ()
    in
    Alcotest.(check int "has correct meta" 3 meta);
    Alcotest.(
      check (list alcotest) "has all users" [ user3; user2; user1 ] actual_users);
    let%lwt actual_users, meta =
      UserService.search ~sort:`Asc ~filter:"%user%" ~limit:10 ()
    in
    Alcotest.(check int "has correct meta" 3 meta);
    Alcotest.(
      check (list alcotest) "has all users" [ user1; user2; user3 ] actual_users);
    Lwt.return ()
  ;;

  module Web = struct
    let fake_token = "faketoken"

    let read_token user_id token ~k =
      if String.equal k "user_id" && String.equal token fake_token
      then Lwt.return @@ Some user_id
      else Lwt.return None
    ;;

    let find_user id =
      if String.equal id "1"
      then
        Lwt.return
        @@ Some
             Sihl.Contract.User.
               { id = "1"
               ; email = "foo@example.com"
               ; username = None
               ; password = "123123"
               ; status = "active"
               ; admin = false
               ; confirmed = false
               ; created_at = Ptime_clock.now ()
               ; updated_at = Ptime_clock.now ()
               }
      else failwith "Invalid user id provided"
    ;;

    let user_from_token _ () =
      let%lwt () = Sihl.Cleaner.clean_all () in
      let%lwt user =
        UserService.create
          ~email:"foo@example.com"
          ~username:None
          ~password:"123123"
          ~admin:false
          ~confirmed:false
        |> Lwt.map Result.get_ok
      in
      let read_token = read_token user.Sihl_user.id in
      let token_header = Format.sprintf "Bearer %s" fake_token in
      let req =
        Opium.Request.get "/some/path/login"
        |> Opium.Request.add_header ("authorization", token_header)
      in
      let handler req =
        let%lwt user = UserService.Web.user_from_token read_token req in
        let email = Option.map (fun user -> user.Sihl_user.email) user in
        Alcotest.(
          check (option string) "has same email" (Some "foo@example.com") email);
        Lwt.return @@ Opium.Response.of_plain_text ""
      in
      let%lwt _ = handler req in
      Lwt.return ()
    ;;

    let user_from_session _ () =
      let%lwt () = Sihl.Cleaner.clean_all () in
      let%lwt user =
        UserService.create
          ~email:"foo@example.com"
          ~username:None
          ~password:"123123"
          ~admin:false
          ~confirmed:false
        |> Lwt.map Result.get_ok
      in
      let cookie =
        Sihl.Web.Response.of_plain_text ""
        |> Sihl.Web.Session.set [ "user_id", user.Sihl_user.id ]
        |> Sihl.Web.Response.cookie "_session"
        |> Option.get
      in
      let req =
        Opium.Request.get "/some/path/login"
        |> Opium.Request.add_cookie cookie.Sihl.Web.Cookie.value
      in
      let handler req =
        let%lwt user = UserService.Web.user_from_session req in
        let email = Option.map (fun user -> user.Sihl_user.email) user in
        Alcotest.(
          check (option string) "has same email" (Some "foo@example.com") email);
        Lwt.return @@ Opium.Response.of_plain_text ""
      in
      let%lwt _ = handler req in
      Lwt.return ()
    ;;
  end

  let suite =
    [ ( "user service"
      , [ test_case "validate valid password" `Quick validate_valid_password
        ; test_case "validate invalid password" `Quick validate_invalid_password
        ; test_case "json serialization" `Quick json_serialization
        ; test_case "update details" `Quick update_details
        ; test_case "update password" `Quick update_password
        ; test_case "update password fails" `Quick update_password_fails
        ; test_case
            "filter users by email returns single user"
            `Quick
            filter_users_by_email_returns_single_user
        ; test_case
            "filter users by email returns all users"
            `Quick
            filter_users_by_email_returns_all_users
        ; test_case "sort users" `Quick sort_users
        ] )
    ; ( "web"
      , [ test_case "user from token" `Quick Web.user_from_token
        ; test_case "user from session" `Quick Web.user_from_session
        ] )
    ]
  ;;
end
