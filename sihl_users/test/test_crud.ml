open Base

let ok_json_string = {|{"msg":"ok"}|}

let ( let* ) = Lwt.bind

let url path = "http://localhost:3000/users" ^ path

let test_user_fetches_all_users_fails _ () =
  let* () = Sihl_core.Manage.clean () in
  let* _ =
    Sihl_core.Test.seed
    @@ Sihl_users.Seed.user ~email:"user1@example.com" ~password:"foobar"
  in
  let* _, token =
    Sihl_core.Test.seed
    @@ Sihl_users.Seed.logged_in_user ~email:"user2@example.com"
         ~password:"foobar"
  in
  let token = Sihl_users.Model.Token.value token in
  let headers =
    Cohttp.Header.of_list [ ("authorization", "Bearer " ^ token) ]
  in
  let* resp, _ =
    Cohttp_lwt_unix.Client.get ~headers (Uri.of_string @@ url "/users/")
  in
  let status = resp |> Cohttp.Response.status |> Cohttp.Code.code_of_status in
  let () = Alcotest.(check int) "Returns not permissions" 403 status in
  Lwt.return @@ ()

let test_admin_fetches_all_users _ () =
  let* () = Sihl_core.Manage.clean () in
  let* _ =
    Sihl_core.Test.seed
    @@ Sihl_users.Seed.user ~email:"user1@example.com" ~password:"foobar"
  in
  let* _, token =
    Sihl_core.Test.seed
    @@ Sihl_users.Seed.logged_in_admin ~email:"admin@example.com"
         ~password:"password"
  in
  let token = Sihl_users.Model.Token.value token in
  let headers =
    Cohttp.Header.of_list [ ("authorization", "Bearer " ^ token) ]
  in
  let* _, body =
    Cohttp_lwt_unix.Client.get ~headers (Uri.of_string @@ url "/users/")
  in
  let* body = Cohttp_lwt.Body.to_string body in
  let users_length =
    body |> Yojson.Safe.from_string
    |> Sihl_users.Handler.GetUsers.body_out_of_yojson |> Result.ok_or_failwith
    |> List.length
  in
  let () = Alcotest.(check int) "Returns two users" 2 users_length in
  Lwt.return @@ ()

let test_user_updates_password _ () =
  let* () = Sihl_core.Manage.clean () in
  let* _, token =
    Sihl_core.Test.seed
    @@ Sihl_users.Seed.logged_in_user ~email:"user1@example.com"
         ~password:"foobar"
  in
  let token = Sihl_users.Model.Token.value token in
  let body =
    {|
       {
         "email": "user1@example.com",
         "old_password": "foobar",
         "new_password": "newpassword"
       }
|}
  in
  let headers =
    Cohttp.Header.of_list [ ("authorization", "Bearer " ^ token) ]
  in
  let* _, body =
    Cohttp_lwt_unix.Client.post ~headers
      ~body:(Cohttp_lwt.Body.of_string body)
      (Uri.of_string @@ url "/update-password/")
  in
  let* body = Cohttp_lwt.Body.to_string body in
  let _ = Alcotest.(check string) "Returns ok" ok_json_string body in
  let base64 = Base64.encode_exn "user1@example.com:newpassword" in
  let headers =
    Cohttp.Header.of_list [ ("authorization", "Basic " ^ base64) ]
  in
  let* resp, _ =
    Cohttp_lwt_unix.Client.get ~headers (Uri.of_string @@ url "/login/")
  in
  let status = resp |> Cohttp.Response.status |> Cohttp.Code.code_of_status in
  Lwt.return @@ Alcotest.(check int) "Can login" 200 status

let test_user_updates_others_password_fails _ () =
  let* () = Sihl_core.Manage.clean () in
  let* _, token =
    Sihl_core.Test.seed
    @@ Sihl_users.Seed.logged_in_user ~email:"user1@example.com"
         ~password:"foobar1"
  in
  let* _ =
    Sihl_core.Test.seed
    @@ Sihl_users.Seed.user ~email:"user2@example.com" ~password:"foobar2"
  in
  let token = Sihl_users.Model.Token.value token in
  let body =
    {|
       {
         "email": "user2@example.com",
         "old_password": "foobar2",
         "new_password": "newpassword"
       }
|}
  in
  let headers =
    Cohttp.Header.of_list [ ("authorization", "Bearer " ^ token) ]
  in
  let* resp, _ =
    Cohttp_lwt_unix.Client.post ~headers
      ~body:(Cohttp_lwt.Body.of_string body)
      (Uri.of_string @@ url "/update-password/")
  in
  let status = resp |> Cohttp.Response.status |> Cohttp.Code.code_of_status in
  Lwt.return @@ Alcotest.(check int) "Can not change others password" 403 status

let test_user_updates_own_details _ () =
  let* () = Sihl_core.Manage.clean () in
  let* _, token =
    Sihl_core.Test.seed
    @@ Sihl_users.Seed.logged_in_user ~email:"user1@example.com"
         ~password:"foobar"
  in
  let token = Sihl_users.Model.Token.value token in
  let body =
    {|
       {
         "email": "user1@example.com",
         "username": "newusername",
         "name": "newname",
         "phone": "123"
       }
|}
  in
  let headers =
    Cohttp.Header.of_list [ ("authorization", "Bearer " ^ token) ]
  in
  let* _, body =
    Cohttp_lwt_unix.Client.post ~headers
      ~body:(Cohttp_lwt.Body.of_string body)
      (Uri.of_string @@ url "/update-details/")
  in
  let* body = Cohttp_lwt.Body.to_string body in
  let user =
    body |> Yojson.Safe.from_string |> Sihl_users.Model.User.of_yojson
    |> Result.ok_or_failwith
  in
  let _ =
    Alcotest.(check string) "Has updated username" "newusername" user.username
  in
  let _ = Alcotest.(check string) "Has updated name" "newname" user.name in
  Lwt.return
  @@ Alcotest.(check @@ option string)
       "Has updated phone" (Some "123") user.phone

let test_user_updates_others_details_fails _ () =
  let* () = Sihl_core.Manage.clean () in
  let* _, token =
    Sihl_core.Test.seed
    @@ Sihl_users.Seed.logged_in_user ~email:"user1@example.com"
         ~password:"foobar1"
  in
  let* _ =
    Sihl_core.Test.seed
    @@ Sihl_users.Seed.logged_in_user ~email:"user2@example.com"
         ~password:"foobar2"
  in
  let token = Sihl_users.Model.Token.value token in
  let body =
    {|
       {
         "email": "user2@example.com",
         "username": "newusername",
         "name": "newname",
         "phone": "123"
       }
|}
  in
  let headers =
    Cohttp.Header.of_list [ ("authorization", "Bearer " ^ token) ]
  in
  let* resp, _ =
    Cohttp_lwt_unix.Client.post ~headers
      ~body:(Cohttp_lwt.Body.of_string body)
      (Uri.of_string @@ url "/update-details/")
  in
  let status = resp |> Cohttp.Response.status |> Cohttp.Code.code_of_status in
  Lwt.return @@ Alcotest.(check int) "Not allowed to update" 403 status

let test_admin_sets_password _ () =
  let* () = Sihl_core.Manage.clean () in
  let* _, token =
    Sihl_core.Test.seed
    @@ Sihl_users.Seed.logged_in_admin ~email:"admin@example.com"
         ~password:"password"
  in
  let* user, _ =
    Sihl_core.Test.seed
    @@ Sihl_users.Seed.logged_in_user ~email:"user1@example.com"
         ~password:"foobar"
  in
  let token = Sihl_users.Model.Token.value token in
  let user_id = user.id in
  let body =
    [%string
      {|
       {
         "user_id": "$user_id",
         "password": "newpassword"
       }
|}]
  in
  let headers =
    Cohttp.Header.of_list [ ("authorization", "Bearer " ^ token) ]
  in
  let* resp, _ =
    Cohttp_lwt_unix.Client.post ~headers
      ~body:(Cohttp_lwt.Body.of_string body)
      (Uri.of_string @@ url "/set-password/")
  in
  let status = resp |> Cohttp.Response.status |> Cohttp.Code.code_of_status in
  let _ = Alcotest.(check int) "Can set password" 200 status in
  let base64 = Base64.encode_exn "user1@example.com:newpassword" in
  let headers =
    Cohttp.Header.of_list [ ("authorization", "Basic " ^ base64) ]
  in
  let* resp, _ =
    Cohttp_lwt_unix.Client.get ~headers (Uri.of_string @@ url "/login/")
  in
  let status = resp |> Cohttp.Response.status |> Cohttp.Code.code_of_status in
  Lwt.return @@ Alcotest.(check int) "Can login" 200 status
