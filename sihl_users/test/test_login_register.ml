open Core

let ok_json_string = {|{"msg":"ok"}|}

let ( let* ) = Lwt.bind

let url path = "http://localhost:3000/users" ^ path

let test_register_user_login_and_own_user _ () =
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
      (Uri.of_string @@ url "/register/")
  in
  let* body = Cohttp_lwt.Body.to_string body in
  let () = Alcotest.(check string) "Returns ok" ok_json_string body in
  let headers =
    Cohttp.Header.of_list
      [ ("authorization", "Basic Zm9vYmFyQGV4YW1wbGUuY29tOjEyMw==") ]
  in
  let* _, body =
    Cohttp_lwt_unix.Client.get ~headers (Uri.of_string @@ url "/login/")
  in
  let* body = Cohttp_lwt.Body.to_string body in
  let Sihl_users.Handler.Login.{ token } =
    body |> Yojson.Safe.from_string
    |> Sihl_users.Handler.Login.body_out_of_yojson |> Result.ok_or_failwith
  in
  let () =
    Alcotest.(check bool) "Returns token" true (not @@ String.is_empty token)
  in
  let headers =
    Cohttp.Header.of_list [ ("authorization", "Bearer " ^ token) ]
  in
  let* _, body =
    Cohttp_lwt_unix.Client.get ~headers (Uri.of_string @@ url "/users/me/")
  in
  let* body = body |> Cohttp_lwt.Body.to_string in
  let Sihl_users.Handler.GetMe.{ email; _ } =
    body |> Yojson.Safe.from_string
    |> Sihl_users.Handler.GetMe.body_out_of_yojson |> Result.ok_or_failwith
  in

  let () =
    Alcotest.(check string) "Returns own email" "foobar@example.com" email
  in
  Lwt.return @@ ()

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

let test_register_existing_user_fails _ () =
  let* () = Sihl_users.App.clean () in
  let* () =
    Sihl_core.Test.seed
      [ Sihl_users.Seed.user ~email:"foobar@example.com" ~password:"321" ]
  in
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
  let* resp, _ =
    Cohttp_lwt_unix.Client.post
      ~body:(Cohttp_lwt.Body.of_string body)
      (Uri.of_string "http://localhost:3000/users/register/")
  in
  let status = resp |> Cohttp.Response.status |> Cohttp.Code.code_of_status in
  Lwt.return @@ Alcotest.(check int) "Returns bad request status" 400 status
