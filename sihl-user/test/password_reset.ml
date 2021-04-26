open Alcotest_lwt

module Make
    (UserService : Sihl.Contract.User.Sig)
    (PasswordResetService : Sihl.Contract.Password_reset.Sig) =
struct
  let reset_password_suceeds _ () =
    let%lwt () = Sihl.Cleaner.clean_all () in
    let%lwt _ =
      UserService.create_user "foo@example.com" ~password:"123456789"
    in
    let%lwt token =
      PasswordResetService.create_reset_token ~email:"foo@example.com"
      |> Lwt.map (Option.to_result ~none:"User with email not found")
      |> Lwt.map Result.get_ok
    in
    let%lwt () =
      PasswordResetService.reset_password
        ~token
        ~password:"newpassword"
        ~password_confirmation:"newpassword"
      |> Lwt.map Result.get_ok
    in
    let%lwt _ =
      UserService.login "foo@example.com" ~password:"newpassword"
      |> Lwt.map Result.get_ok
    in
    Lwt.return ()
  ;;

  let suite =
    [ ( "password reset"
      , [ test_case "password reset" `Quick reset_password_suceeds ] )
    ]
  ;;
end
