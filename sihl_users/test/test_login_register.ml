open Base

let ok_json_string = {|{"msg":"ok"}|}

let ( let* ) = Lwt.bind

let url path = "http://localhost:3000/users" ^ path

let test_register_user_login_and_own_user _ () =
  let* () = Sihl_core.Manage.clean () in
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
  let base64 = Base64.encode_exn "foobar@example.com:123" in
  let headers =
    Cohttp.Header.of_list [ ("authorization", "Basic " ^ base64) ]
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
  let Sihl_users.Model.User.{ email; _ } =
    body |> Yojson.Safe.from_string |> Sihl_users.Model.User.of_yojson
    |> Result.ok_or_failwith
  in

  let () =
    Alcotest.(check string) "Returns own email" "foobar@example.com" email
  in
  Lwt.return @@ ()

let test_register_invalid_user_fails _ () =
  let* () = Sihl_core.Manage.clean () in
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
  let* () = Sihl_core.Manage.clean () in
  let* _ =
    Sihl_core.Test.seed
    @@ Sihl_users.Seed.user ~email:"foobar@example.com" ~password:"321"
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

let test_fetch_user_after_logout_fails _ () =
  let* () = Sihl_core.Manage.clean () in
  let* _, token =
    Sihl_core.Test.seed
    @@ Sihl_users.Seed.logged_in_user ~email:"foobar@example.com"
         ~password:"321"
  in
  let token = Sihl_users.Model.Token.value token in
  let headers =
    Cohttp.Header.of_list [ ("authorization", "Bearer " ^ token) ]
  in
  let* response, _ =
    Cohttp_lwt_unix.Client.delete ~headers (Uri.of_string @@ url "/logout/")
  in
  let status =
    response |> Cohttp.Response.status |> Cohttp.Code.code_of_status
  in
  let _ = Alcotest.(check int) "Returns ok, logout succeeded" 200 status in
  let* response, _ =
    Cohttp_lwt_unix.Client.get ~headers (Uri.of_string @@ url "/users/me/")
  in
  let status =
    response |> Cohttp.Response.status |> Cohttp.Code.code_of_status
  in
  Lwt.return @@ Alcotest.(check int) "Returns not authorized" 401 status

let test_login_with_wrong_credentials_fails _ () =
  let* () = Sihl_core.Manage.clean () in
  let* _ =
    Sihl_core.Test.seed
    @@ Sihl_users.Seed.user ~email:"foobar@example.com" ~password:"321"
  in
  let auth = "foobar@example.com:wrongpassword" |> Base64.encode_exn in
  let headers = Cohttp.Header.of_list [ ("authorization", "Basic " ^ auth) ] in
  let* response, _ =
    Cohttp_lwt_unix.Client.get ~headers (Uri.of_string @@ url "/login/")
  in
  let status =
    response |> Cohttp.Response.status |> Cohttp.Code.code_of_status
  in
  Lwt.return @@ Alcotest.(check int) "Returns not authorized status" 401 status
