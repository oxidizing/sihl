open Alcotest_lwt
open Lwt.Syntax

let reset_password_suceeds _ () =
  let* () = Sihl_core.Cleaner.clean_all () in
  let* _ =
    Sihl_facade.User.create_user
      ~email:"foo@example.com"
      ~password:"123456789"
      ~username:None
  in
  let* token =
    Sihl_facade.Password_reset.create_reset_token ~email:"foo@example.com"
    |> Lwt.map (Option.to_result ~none:"User with email not found")
    |> Lwt.map Result.get_ok
  in
  let* () =
    Sihl_facade.Password_reset.reset_password
      ~token
      ~password:"newpassword"
      ~password_confirmation:"newpassword"
    |> Lwt.map Result.get_ok
  in
  let* _ =
    Sihl_facade.User.login ~email:"foo@example.com" ~password:"newpassword"
    |> Lwt.map Result.get_ok
  in
  Lwt.return ()
;;

let suite =
  [ ( "password reset"
    , [ test_case "password reset" `Quick reset_password_suceeds ] )
  ]
;;
