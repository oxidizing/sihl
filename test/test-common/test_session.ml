open Base

let ( let* ) = Lwt.bind

let test_anonymous_request_returns_cookie _ () =
  (* Inject ctx somehow *)
  (* let* req =
   *   Uri.of_string "/foobar/" |> Cohttp.Request.make
   *   |> Opium_kernel.Request.create |> Sihl.Core.Db.request_with_connection
   * in
   * let middleware_to_test = Sihl.Middleware.session () in
   * let* _ =
   *   Opium_kernel.Rock.Middleware.apply middleware_to_test
   *     (fun _ -> Lwt.return @@ Opium_kernel.Response.create ())
   *     req
   * in *)
  let ctx = Sihl.Test.context () in
  let (module Service : Sihl.Session.Sig.SERVICE) =
    Sihl.Core.Container.fetch_service_exn Sihl.Session.Sig.key
  in
  let* sessions =
    Service.get_all_sessions ctx
    |> Lwt_result.map_err Sihl.Core.Err.raise_server
    |> Lwt.map Result.ok_exn
  in
  let () =
    Alcotest.(check int) "Has created session" 1 (List.length sessions)
  in
  Lwt.return ()

let test_requests_persist_session_variables _ () =
  (* Create request with injected database into request env *)
  (* let* req =
   *   Uri.of_string "/foobar/" |> Cohttp.Request.make
   *   |> Opium_kernel.Request.create |> Sihl.Core.Db.request_with_connection
   * in
   * let middleware_to_test = Sihl.Middleware.session () in
   * let* _ =
   *   Opium_kernel.Rock.Middleware.apply middleware_to_test
   *     (fun req ->
   *       let* () =
   *         Sihl.Session.set_value ~key:"foo" ~value:"bar" req
   *         |> Lwt_result.map_err Sihl.Core.Err.raise_server
   *         |> Lwt.map Result.ok_exn
   *       in
   *       Lwt.return @@ Opium_kernel.Response.create ())
   *     req
   * in *)
  let ctx = Sihl.Test.context () in
  let (module Service : Sihl.Session.Sig.SERVICE) =
    Sihl.Core.Container.fetch_service_exn Sihl.Session.Sig.key
  in
  let* session =
    Service.get_all_sessions ctx
    |> Lwt_result.map_err Sihl.Core.Err.raise_server
    |> Lwt.map Result.ok_exn |> Lwt.map List.hd_exn
  in
  let () =
    Alcotest.(check (option string))
      "Has created session with session value" (Some "bar")
      (Sihl.Session.get "foo" session)
  in
  Lwt.return ()
