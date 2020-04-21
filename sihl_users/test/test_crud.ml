open Core

let ok_json_string = {|{"msg":"ok"}|}

let ( let* ) = Lwt.bind

let url path = "http://localhost:3000/users" ^ path

let test_user_fetches_all_users_fails _ () =
  let* _ = Sihl_users.App.clean () in
  let* _ =
    Sihl_core.Test.seed
    @@ Sihl_users.Seed.user ~email:"user1@example.com" ~password:"foobar"
  in
  let* token =
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
  let* _ = Sihl_users.App.clean () in
  let* _ =
    Sihl_core.Test.seed
    @@ Sihl_users.Seed.user ~email:"user1@example.com" ~password:"foobar"
  in
  let* token =
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

let test_user_updates_password = Lwt.return ()

let test_user_updates_own_details = Lwt.return ()

let test_user_updates_other_details_fails = Lwt.return ()

let test_admin_sets_password = Lwt.return ()
