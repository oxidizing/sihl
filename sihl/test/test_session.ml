open Base

let ( let* ) = Lwt.bind

let session_not_expired _ () =
  let expire_date =
    Option.value_exn
      ( 60 * 60 * 24
      |> Ptime.Span.of_int_s
      |> Ptime.add_span (Ptime_clock.now ()) )
  in
  let session = Sihl.Session.create ~expire_date (Ptime_clock.now ()) in
  Lwt.return
  @@ Alcotest.(
       check bool "is not expired" false
         (Sihl.Session.is_expired (Ptime_clock.now ()) session))

let test_anonymous_request_returns_cookie _ () =
  let* () = Sihl.Run.Manage.clean () in
  (* Create request with injected database into request env *)
  let* req =
    Uri.of_string "/foobar/" |> Cohttp.Request.make
    |> Opium_kernel.Request.create |> Sihl.Core.Db.request_with_connection
  in
  let middleware_to_test = Sihl.Middleware.session () in
  let* _ =
    Opium_kernel.Rock.Middleware.apply middleware_to_test
      (fun _ -> Lwt.return @@ Opium_kernel.Response.create ())
      req
  in
  let* req = Sihl.Run.Test.request_with_connection () in
  let (module Service : Sihl.Session.Sig.SERVICE) =
    Sihl.Core.Container.fetch_exn Sihl.Session.Sig.key
  in
  let* sessions =
    Service.get_all_sessions req
    |> Lwt_result.map_err Sihl.Core.Err.raise_server
    |> Lwt.map Result.ok_exn
  in
  let () =
    Alcotest.(check int) "Has created session" 1 (List.length sessions)
  in
  Lwt.return ()

let test_requests_persist_session_variables _ () =
  let* () = Sihl.Run.Manage.clean () in
  (* Create request with injected database into request env *)
  let* req =
    Uri.of_string "/foobar/" |> Cohttp.Request.make
    |> Opium_kernel.Request.create |> Sihl.Core.Db.request_with_connection
  in
  let middleware_to_test = Sihl.Middleware.session () in
  let* _ =
    Opium_kernel.Rock.Middleware.apply middleware_to_test
      (fun req ->
        let* () =
          Sihl.Session.set_value ~key:"foo" ~value:"bar" req
          |> Lwt_result.map_err Sihl.Core.Err.raise_server
          |> Lwt.map Result.ok_exn
        in
        Lwt.return @@ Opium_kernel.Response.create ())
      req
  in
  let* req = Sihl.Run.Test.request_with_connection () in
  let (module Service : Sihl.Session.Sig.SERVICE) =
    Sihl.Core.Container.fetch_exn Sihl.Session.Sig.key
  in
  let* session =
    Service.get_all_sessions req
    |> Lwt_result.map_err Sihl.Core.Err.raise_server
    |> Lwt.map Result.ok_exn |> Lwt.map List.hd_exn
  in
  let () =
    Alcotest.(check (option string))
      "Has created session with session value" (Some "bar")
      (Sihl.Session.get "foo" session)
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
