let suite =
  [
    ( "login & register",
      [ (* test_case "register user with, login and fetch own user" `Quick
         *   Test_login_register.test_register_user_login_and_own_user;
         * test_case "register user with invalid body fails" `Quick
         *   Test_login_register.test_register_invalid_user_fails;
         * test_case "register user with existing email fails" `Quick
         *   Test_login_register.test_register_existing_user_fails;
         * test_case "user fetched own user after logout fails" `Quick
         *   Test_login_register.test_fetch_user_after_logout_fails;
         * test_case "user login with wrong credentials fails" `Quick
         *   Test_login_register.test_login_with_wrong_credentials_fails; *) ]
    );
    ( "crud",
      [ (* test_case "user fetches all users fails" `Quick
         *   Test_crud.test_user_fetches_all_users_fails;
         * test_case "admin fetches all users" `Quick
         *   Test_crud.test_admin_fetches_all_users;
         * test_case "user updated own password" `Quick
         *   Test_crud.test_user_updates_password;
         * test_case "user updates own details" `Quick
         *   Test_crud.test_user_updates_own_details;
         * test_case "user updates others details fails" `Quick
         *   Test_crud.test_user_updates_others_details_fails;
         * test_case "user sets password" `Quick Test_crud.test_admin_sets_password; *) ]
    );
    ( "email",
      [ (* test_case "user registers and confirms email" `Quick
         *   Test_email.test_user_registers_and_confirms_email;
         * test_case "user resets password" `Quick
         *   Test_email.test_user_resets_password;
         * test_case "user uses reset token twice fails" `Quick
         *   Test_email.test_user_uses_reset_token_twice_fails; *) ] );
  ]

let () = ()

(* let db_name, project =
 *   match Sys.getenv "DATABASE" with
 *   | Some "mariadb" -> ("MariaDB", Run_mariadb.project)
 *   | _ -> ("Postgres", Run_postgresql.project)
 * in
 * Lwt_main.run
 *   (let* () = Sihl.Run.Manage.start project in
 *    let* () = Sihl.Run.Manage.migrate () in
 *    let* () = run ("user management with " ^ db_name) suite in
 *    Sihl.Run.Manage.stop ()) *)
