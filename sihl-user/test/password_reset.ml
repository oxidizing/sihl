open Alcotest_lwt
open Lwt.Syntax

module Make
    (UserService : Sihl_contract.User.Sig)
    (PasswordResetService : Sihl_contract.Password_reset.Sig) =
struct
  let reset_password_suceeds _ () =
    let* () = Sihl_persistence.Repository.clean_all () in
    let* _ = UserService.Seed.user () ~email:"foo@example.com" ~password:"123456789" in
    let* token =
      PasswordResetService.create_reset_token ~email:"foo@example.com"
      |> Lwt.map (Option.to_result ~none:"User with email not found")
      |> Lwt.map Result.get_ok
    in
    let token = Sihl_type.Token.value token in
    let* () =
      PasswordResetService.reset_password
        ~token
        ~password:"newpassword"
        ~password_confirmation:"newpassword"
      |> Lwt.map Result.get_ok
    in
    let* _ =
      UserService.login ~email:"foo@example.com" ~password:"newpassword"
      |> Lwt.map Result.get_ok
    in
    Lwt.return ()
  ;;

  let suite =
    [ "password reset", [ test_case "password reset" `Quick reset_password_suceeds ] ]
  ;;
end
