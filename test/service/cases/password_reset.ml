open Alcotest_lwt
open Lwt.Syntax

module Make
    (UserService : Sihl.User.Sig.SERVICE)
    (PasswordResetService : Sihl.Password_reset.Sig.SERVICE) =
struct
  module UserSeed = Sihl.User.Seed.Make (UserService)

  let reset_password_suceeds _ () =
    let ctx = Sihl.Core.Ctx.create () in
    let* () = Sihl.Repository.Service.clean_all ctx in
    let* _ = UserSeed.user ctx ~email:"foo@example.com" ~password:"123456789" in
    let* token =
      PasswordResetService.create_reset_token ctx ~email:"foo@example.com"
      |> Lwt.map (Option.to_result ~none:"User with email not found")
      |> Lwt.map Result.get_ok
    in
    let token = Sihl.Token.value token in
    let* () =
      PasswordResetService.reset_password
        ctx
        ~token
        ~password:"newpassword"
        ~password_confirmation:"newpassword"
      |> Lwt.map Result.get_ok
    in
    let* _ =
      UserService.login ctx ~email:"foo@example.com" ~password:"newpassword"
      |> Lwt.map Result.get_ok
    in
    Lwt.return ()
  ;;

  let test_suite =
    "password reset", [ test_case "password reset" `Quick reset_password_suceeds ]
  ;;
end
