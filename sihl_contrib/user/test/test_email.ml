open Base

let ( let* ) = Lwt.bind

let url path = "http://localhost:3000/users" ^ path

let extract_token text =
  let regexp = Pcre.regexp {|token=([\w|\-]*)|} in
  Option.value_exn ~message:"no match found"
    (Sihl.Core.Regex.extract_last regexp text)

(* let test_user_registers_and_confirms_email _ () =
 *   let* _ = Sihl.Run.Manage.clean () in
 *   let body =
 *     {|
 *        {
 *          "email": "user1@example.com",
 *          "username": "user1",
 *          "password": "123"
 *        }
 * |}
 *   in
 *   let* _ =
 *     Cohttp_lwt_unix.Client.post
 *       ~body:(Cohttp_lwt.Body.of_string body)
 *       (Uri.of_string @@ url "/register/")
 *   in
 *   let email = Sihl.Email.DevInbox.get () in
 *   let token = email |> Sihl.Email.content |> extract_token in
 *   let* _ =
 *     Cohttp_lwt_unix.Client.get
 *       (Uri.of_string @@ url ("/confirm-email/?token=" ^ token))
 *   in
 *   let base64 = Base64.encode_exn "user1@example.com:123" in
 *   let headers =
 *     Cohttp.Header.of_list [ ("authorization", "Basic " ^ base64) ]
 *   in
 *   let* _, body =
 *     Cohttp_lwt_unix.Client.get ~headers (Uri.of_string @@ url "/login/")
 *   in
 *   let* body = Cohttp_lwt.Body.to_string body in
 *   let Sihl_user.Handler.Login.{ token; _ } =
 *     body |> Yojson.Safe.from_string
 *     |> Sihl_user.Handler.Login.body_out_of_yojson |> Result.ok_or_failwith
 *   in
 *   let () =
 *     Alcotest.(check bool) "Returns token" true (not @@ String.is_empty token)
 *   in
 *   let headers =
 *     Cohttp.Header.of_list [ ("authorization", "Bearer " ^ token) ]
 *   in
 *   let* _, body =
 *     Cohttp_lwt_unix.Client.get ~headers (Uri.of_string @@ url "/users/me/")
 *   in
 *   let* body = body |> Cohttp_lwt.Body.to_string in
 *   let confirmed =
 *     body |> Yojson.Safe.from_string |> Sihl.User.of_yojson
 *     |> Result.ok_or_failwith |> Sihl.User.confirmed
 *   in
 *   let () = Alcotest.(check bool) "Has confirmed email" true confirmed in
 *   Lwt.return @@ () *)

let test_user_resets_password _ () =
  let* _ = Sihl.Run.Manage.clean () in
  let* _ =
    Sihl.Run.Test.seed
    @@ Sihl_user.Seed.user ~email:"user1@example.com" ~password:"password"
  in
  let body = {|{"email": "user1@example.com"}|} in
  let* _ =
    Cohttp_lwt_unix.Client.post
      ~body:(Cohttp_lwt.Body.of_string body)
      (Uri.of_string @@ url "/request-password-reset/")
  in
  let email = Sihl.Email.DevInbox.get () in
  let token = email |> Sihl.Email.content |> extract_token in
  let body =
    Printf.sprintf {|{"token": "%s", "new_password": "newpassword"}|} token
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
  let* _ = Sihl.Run.Manage.clean () in
  let* _ =
    Sihl.Run.Test.seed
    @@ Sihl_user.Seed.user ~email:"user1@example.com" ~password:"password"
  in
  let* _ =
    Sihl.Run.Test.seed
    @@ Sihl_user.Seed.admin ~email:"admin@example.com" ~password:"password"
  in
  let body = {|{"email": "user1@example.com"}|} in
  let* _ =
    Cohttp_lwt_unix.Client.post
      ~body:(Cohttp_lwt.Body.of_string body)
      (Uri.of_string @@ url "/request-password-reset/")
  in
  let email = Sihl.Email.DevInbox.get () in
  let token = email |> Sihl.Email.content |> extract_token in
  let body =
    Printf.sprintf {|{"token": "%s", "new_password": "newpassword"}|} token
  in
  let* _ =
    Cohttp_lwt_unix.Client.post
      ~body:(Cohttp_lwt.Body.of_string body)
      (Uri.of_string @@ url "/reset-password/")
  in
  let body =
    Printf.sprintf {|{"token": "%s", "new_password": "anotherpassword"}|} token
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
