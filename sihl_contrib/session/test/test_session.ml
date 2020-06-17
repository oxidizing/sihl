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
  let (module Repository : Sihl_session.Repo.REPOSITORY) =
    Sihl.Core.Registry.get Sihl_session.Bind.Repository.key
  in
  let* sessions = Repository.get_all |> Sihl.Core.Db.query_db request in
  let length = sessions |> Result.map ~f:List.length in
  let () =
    Alcotest.(check (result int Sihl.Error.testable))
      "Has created session" (Ok 1) length
  in
  Lwt.return ()

let test_requests_persist_session_variables _ () =
  let* () = Sihl.Run.Manage.clean () in
  (* Create request with injected database into request env *)
  let* req =
    Uri.of_string "/foobar/" |> Cohttp.Request.make
    |> Opium_kernel.Request.create |> Sihl.Core.Db.request_with_connection
  in
  let middleware_to_test = Sihl_session.middleware () in
  let* _ =
    Opium_kernel.Rock.Middleware.apply middleware_to_test
      (fun req ->
        let* _ = Sihl_session.set ~key:"foo" ~value:"bar" req in
        Lwt.return @@ Opium_kernel.Response.create ())
      req
  in
  let* request = Sihl.Run.Test.request_with_connection () in
  let (module Repository : Sihl_session.Repo.REPOSITORY) =
    Sihl.Core.Registry.get Sihl_session.Bind.Repository.key
  in
  let* sessions = Repository.get_all |> Sihl.Core.Db.query_db request in
  let session =
    sessions |> Result.map ~f:List.hd_exn
    |> Result.map ~f:(fun session -> Sihl.Session.get "foo" session)
  in
  let () =
    Alcotest.(check (result (option string) Sihl.Error.testable))
      "Has created session with session value" (Ok (Some "bar")) session
  in
  Lwt.return ()

let test_set_session_variable _ () =
  let open Sihl.Session in
  let session = create (Ptime_clock.now ()) in
  Alcotest.(check (option string))
    "Has no session variable" None (get "foo" session);
  let session = set ~key:"foo" ~value:"bar" session in
  Logs.debug (fun m -> m "got new session");
  Alcotest.(check (option string))
    "Has a session variable" (Some "bar") (get "foo" session);
  let session = set ~key:"foo" ~value:"baz" session in
  Alcotest.(check (option string))
    "Has overridden session variable" (Some "baz") (get "foo" session);
  Alcotest.(check (option string))
    "Has no other session variable" None (get "other" session);
  Lwt.return ()
