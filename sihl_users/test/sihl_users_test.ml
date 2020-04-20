let ok_json_string = {|{"msg":"ok"}|}

let ( let* ) = Lwt.bind

let test_register_user _ () =
  let* _ = Sihl_users.App.clean () in
  let body =
    {|
       {
         "email": "foobar@example.com",
         "username": "foobar",
         "password": "123",
         "name": "Foo"
       }
|}
  in
  let* _, body =
    Cohttp_lwt_unix.Client.post
      ~body:(Cohttp_lwt.Body.of_string body)
      (Uri.of_string "http://localhost:3000/users/register/")
  in
  let* body = Cohttp_lwt.Body.to_string body in
  Lwt.return @@ Alcotest.(check string) "Returns ok" ok_json_string body

let test_register_invalid_user_fails _ () =
  let* _ = Sihl_users.App.clean () in
  let body =
    {|
       {
         "email": "foobar@example.com",
         "password": "123",
         "name": "Foo"
       }
|}
  in
  let* resp, _ =
    Cohttp_lwt_unix.Client.post
      ~body:(Cohttp_lwt.Body.of_string body)
      (Uri.of_string "http://localhost:3000/users/register/")
  in
  let status = resp |> Cohttp.Response.status |> Cohttp.Code.code_of_status in
  Lwt.return @@ Alcotest.(check int) "Returns bad request status" 400 status

let () =
  let open Alcotest_lwt in
  let _ = Sihl_users.App.start () in
  Lwt_main.run
    (let* _ =
       Sihl_core.Db.Migrate.execute [ Sihl_users.Migration.migrations ]
     in
     run "LwtUtils"
       [
         ( "user management",
           [
             test_case "Register user with valid body" `Quick test_register_user;
             test_case "Register user with invalid body" `Quick
               test_register_invalid_user_fails;
           ] );
       ])
