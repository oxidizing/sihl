open Base

let ( let* ) = Lwt.bind

let test_fetch_any_endpoint_creates_anonymous_session _ () =
  let* () = Sihl.Run.Manage.clean () in
  (* Create request with injected database into request env *)
  let* req =
    Uri.of_string "/foobar/" |> Cohttp.Request.make
    |> Opium_kernel.Request.create |> Sihl.Core.Db.request_with_connection
  in
  let middleware_to_test = Sihl_session.Middleware.session () in
  let* _ =
    Opium_kernel.Rock.Middleware.apply middleware_to_test
      (fun _ -> Lwt.return @@ Opium_kernel.Response.create ())
      req
  in
  let* request = Sihl.Run.Test.request_with_connection () in
  let (module Repository : Sihl_session.Repo_sig.REPOSITORY) =
    Sihl.Core.Registry.get Sihl_session.Bind.Repository.key
  in
  let* sessions = Repository.get_all |> Sihl.Core.Db.query_db request in
  let sessions = sessions |> Result.ok_or_failwith in
  let () =
    Alcotest.(check int) "Has created session" 1 (List.length sessions)
  in
  Lwt.return @@ ()
