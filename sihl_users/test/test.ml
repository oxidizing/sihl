let ( let* ) = Lwt.bind

let () =
  let open Alcotest_lwt in
  let _ = Sihl_users.App.start () in
  Lwt_main.run
    (let* _ =
       Sihl_core.Db.Migrate.execute [ Sihl_users.Migration.migrations ]
     in
     run "user management"
       [
         ( "login & register",
           [
             test_case "register user with, login and fetch own user" `Quick
               Test_login_register.test_register_user_login_and_own_user;
             test_case "register user with invalid body fails" `Quick
               Test_login_register.test_register_invalid_user_fails;
             test_case "register user with existing email fails" `Quick
               Test_login_register.test_register_existing_user_fails;
             test_case "user fetched own user after logout fails" `Quick
               Test_login_register.test_fetch_user_after_logout_fails;
             test_case "user login with wrong credentials fails" `Quick
               Test_login_register.test_login_with_wrong_credentials_fails;
           ] );
         ( "crud",
           [
             test_case "user fetches all users fails" `Quick
               Test_crud.test_user_fetches_all_users_fails;
             test_case "admin fetches all users" `Quick
               Test_crud.test_admin_fetches_all_users;
             test_case "user updated own password" `Quick
               Test_crud.test_user_updates_password;
             test_case "user updated own details" `Quick
               Test_crud.test_user_updates_own_details;
           ] );
       ])
