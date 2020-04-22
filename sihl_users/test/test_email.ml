open Core

let ( let* ) = Lwt.bind

let url path = "http://localhost:3000/users" ^ path

let extract_token text =
  let regexp = Pcre.regexp {|token=([\w|\-]*)|} in
  let result = Pcre.extract ~rex:regexp text in
  Option.value_exn ~message:"no match found"
    (List.nth (result |> Array.to_list) 1)

let test_extract_token_from_email _ () =
  let actual = extract_token "token=abc123" in
  let _ = Alcotest.(check string) "Extract token 1" "abc123" actual in
  let actual = extract_token "foo token=abc123 bar" in
  let _ = Alcotest.(check string) "Extract token 2" "abc123" actual in
  Lwt.return ()

let test_user_registers_and_confirms_email _ () =
  let* () = Sihl_users.App.clean () in
  let body =
    {|
       {
         "email": "user1@example.com",
         "username": "user1",
         "password": "123",
         "name": "User 1"
       }
|}
  in
  let* _ =
    Cohttp_lwt_unix.Client.post
      ~body:(Cohttp_lwt.Body.of_string body)
      (Uri.of_string @@ url "/register/")
  in
  let email = Sihl_core.Email.last_dev_email () in
  let token = extract_token email.text in
  let* _ =
    Cohttp_lwt_unix.Client.get
      (Uri.of_string @@ url ("/confirm-email/?token=" ^ token))
  in
  let base64 = Base64.encode_exn "user1@example.com:123" in
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
  let Sihl_users.Model.User.{ confirmed; _ } =
    body |> Yojson.Safe.from_string |> Sihl_users.Model.User.of_yojson
    |> Result.ok_or_failwith
  in
  let () = Alcotest.(check bool) "Has confirmed email" true confirmed in
  Lwt.return @@ ()

let test_user_resets_password _ () =
  let* () = Sihl_users.App.clean () in
  let* _ =
    Sihl_core.Test.seed
    @@ Sihl_users.Seed.user ~email:"user1@example.com" ~password:"password"
  in
  let body = {|{"email": "user1@example.com"}|} in
  let* _ =
    Cohttp_lwt_unix.Client.post
      ~body:(Cohttp_lwt.Body.of_string body)
      (Uri.of_string @@ url "/request-password-reset/")
  in
  let email = Sihl_core.Email.last_dev_email () in
  let token = extract_token email.text in
  let body =
    [%string {|{"token": "$(token)", "new_password": "newpassword"}|}]
  in
  let* _ =
    Cohttp_lwt_unix.Client.post
      ~body:(Cohttp_lwt.Body.of_string body)
      (Uri.of_string @@ url "/reset-password/")
  in
  let base64 = Base64.encode_exn "user1@example.com:newpassword" in
  let headers =
    Cohttp.Header.of_list [ ("authorization", "Basic " ^ base64) ]
  in
  let* resp, _ =
    Cohttp_lwt_unix.Client.get ~headers (Uri.of_string @@ url "/login/")
  in
  let status =
    resp |> Cohttp_lwt_unix.Response.status |> Cohttp.Code.code_of_status
  in
  Lwt.return @@ Alcotest.(check int) "Can login with new password" 200 status

let test_user_uses_reset_token_twice_fails _ () =
  let* () = Sihl_users.App.clean () in
  let* _ =
    Sihl_core.Test.seed
    @@ Sihl_users.Seed.user ~email:"user1@example.com" ~password:"password"
  in
  let body = {|{"email": "user1@example.com"}|} in
  let* _ =
    Cohttp_lwt_unix.Client.post
      ~body:(Cohttp_lwt.Body.of_string body)
      (Uri.of_string @@ url "/request-password-reset/")
  in
  let email = Sihl_core.Email.last_dev_email () in
  let token = extract_token email.text in
  let body =
    [%string {|{"token": "$(token)", "new_password": "newpassword"}|}]
  in
  let* _ =
    Cohttp_lwt_unix.Client.post
      ~body:(Cohttp_lwt.Body.of_string body)
      (Uri.of_string @@ url "/reset-password/")
  in
  let body =
    [%string {|{"token": "$(token)", "new_password": "anotherpassword"}|}]
  in
  let* resp, _ =
    Cohttp_lwt_unix.Client.post
      ~body:(Cohttp_lwt.Body.of_string body)
      (Uri.of_string @@ url "/reset-password/")
  in
  let status =
    resp |> Cohttp_lwt_unix.Response.status |> Cohttp.Code.code_of_status
  in
  Lwt.return @@ Alcotest.(check int) "Can not use token twice" 400 status
