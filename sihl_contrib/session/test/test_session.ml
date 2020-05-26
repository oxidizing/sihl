open Base

let ( let* ) = Lwt.bind

let test_anonymous_request_returns_cookie _ () =
  let* () = Sihl.Run.Manage.clean () in
  (* Create request with injected database into request env *)
  let* req =
    Uri.of_string "/foobar/" |> Cohttp.Request.make
    |> Opium_kernel.Request.create |> Sihl.Core.Db.request_with_connection
  in
  let middleware_to_test = Sihl_session.middleware () in
  let* _ =
    Opium_kernel.Rock.Middleware.apply middleware_to_test
      (fun _ -> Lwt.return @@ Opium_kernel.Response.create ())
      req
  in
  let* request = Sihl.Run.Test.request_with_connection () in
  let (module Repository : Sihl_session.REPOSITORY) =
    Sihl.Core.Registry.get Sihl_session.Bind.Repository.key
  in
  let* sessions = Repository.get_all |> Sihl.Core.Db.query_db request in
  let sessions = sessions |> Result.ok_or_failwith in
  let () =
    Alcotest.(check int) "Has created session" 1 (List.length sessions)
  in
  Lwt.return ()

let test_set_session_variable _ () =
  let open Sihl_session.Model.Session in
  let session = create () in
  Alcotest.(check (option string))
    "Has no session variable" None (get "foo" session);
  let session = set ~key:"foo" ~value:"bar" session in
  Alcotest.(check (option string))
    "Has a session variable" (Some "bar") (get "foo" session);
  let session = set ~key:"foo" ~value:"baz" session in
  Alcotest.(check (option string))
    "Has overridden session variable" (Some "baz") (get "foo" session);
  Alcotest.(check (option string))
    "Has no other session variable" None (get "other" session);
  Lwt.return ()
