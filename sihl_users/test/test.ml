open Core

let ok_json_string = {|{"msg":"ok"}|}

let ( let* ) = Lwt.bind

let url path = "http://localhost:3000/users" ^ path

let () =
  let open Alcotest_lwt in
  let _ = Sihl_users.App.start () in
  Lwt_main.run
    (let* _ =
       Sihl_core.Db.Migrate.execute [ Sihl_users.Migration.migrations ]
     in
     run "user management"
       [
         ( "user management",
           [
             test_case "Register user with, login and fetch own user" `Quick
               Test_login_register.test_register_user_login_and_own_user;
             test_case "Register user with invalid body fails" `Quick
               Test_login_register.test_register_invalid_user_fails;
             test_case "Register user with existing email fails" `Quick
               Test_login_register.test_register_existing_user_fails;
           ] );
       ])
