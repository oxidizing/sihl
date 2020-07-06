open Base

let ( let* ) = Lwt.bind

let test_anonymous_request_returns_cookie _ () =
  let ctx = Sihl.Core.Ctx.empty |> Sihl.Data.Db.add_pool in
  let* () = Sihl.Data.Repo.clean_all ctx |> Lwt.map Result.ok_or_failwith in
  let stack = [ Sihl.Web.Middleware.session () ] in
  let* _ = Sihl.Test.middleware_stack ctx stack in
  let* sessions =
    Sihl.Session.get_all_sessions ctx |> Lwt.map Result.ok_or_failwith
  in
  let () =
    Alcotest.(check int) "Has created session" 1 (List.length sessions)
  in
  Lwt.return ()

let test_requests_persist_session_variables _ () =
  let ctx = Sihl.Core.Ctx.empty |> Sihl.Data.Db.add_pool in
  let* () = Sihl.Data.Repo.clean_all ctx |> Lwt.map Result.ok_or_failwith in
  let stack = [ Sihl.Web.Middleware.session () ] in
  let handler ctx =
    Logs.debug (fun m -> m "two %s" (Sihl.Core.Ctx.id ctx));
    let* () =
      Sihl.Session.set_value ctx ~key:"foo" ~value:"bar"
      |> Lwt.map Result.ok_or_failwith
    in
    Lwt.return @@ Sihl.Web.Res.html
  in
  let* _ = Sihl.Test.middleware_stack ctx ~handler stack in
  let* session =
    Sihl.Session.get_all_sessions ctx
    |> Lwt.map Result.ok_or_failwith
    |> Lwt.map List.hd_exn
  in
  let () =
    Alcotest.(check (option string))
      "Has created session with session value" (Some "bar")
      (Sihl.Session.get "foo" session)
  in
  Lwt.return ()
