let test_register_user _ () =
  let open Lwt.Infix in
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
  Cohttp_lwt_unix.Client.post
    ~body:(Cohttp_lwt.Body.of_string body)
    (Uri.of_string "http://localhost:3000/users/register/")
  >>= fun (_, body) ->
  body |> Cohttp_lwt.Body.to_string >|= fun body ->
  Alcotest.(check string) "Found a body" "ok" body

let () =
  let open Alcotest_lwt in
  let _ = Sihl_users.App.start () in
  Lwt_main.run
  @@ run "LwtUtils"
       [
         ( "user management",
           [ test_case "Register user" `Quick test_register_user ] );
       ]
