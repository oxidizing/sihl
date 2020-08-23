open Alcotest_lwt
open Base
open Lwt.Syntax

module Make
    (DbService : Sihl.Data.Db.Sig.SERVICE)
    (RepoService : Sihl.Data.Repo.Sig.SERVICE)
    (SessionService : Sihl.Session.Sig.SERVICE) =
struct
  module Middleware = Sihl.Web.Middleware.Session.Make (SessionService)

  let test_anonymous_request_returns_cookie _ () =
    let ctx = Sihl.Core.Ctx.empty |> DbService.add_pool in
    let* () = RepoService.clean_all ctx in
    let stack = [ Middleware.m () ] in
    let* _ = Sihl.Test.middleware_stack ctx stack in
    let* sessions = SessionService.find_all ctx in
    let () =
      Alcotest.(check int "Has created session" 1 (List.length sessions))
    in
    Lwt.return ()

  let test_requests_persist_session_variables _ () =
    let ctx = Sihl.Core.Ctx.empty |> DbService.add_pool in
    let* () = RepoService.clean_all ctx in
    let stack = [ Middleware.m () ] in
    let handler ctx =
      Logs.debug (fun m -> m "two %s" (Sihl.Core.Ctx.id ctx));
      let* () = SessionService.set ctx ~key:"foo" ~value:"bar" in
      Lwt.return @@ Sihl.Web.Res.html
    in
    let* _ = Sihl.Test.middleware_stack ctx ~handler stack in
    let* session = SessionService.find_all ctx |> Lwt.map List.hd_exn in
    let () =
      Alcotest.(
        check (option string) "Has created session with session value"
          (Some "bar")
          (Sihl.Session.get "foo" session))
    in
    Lwt.return ()

  let test_suite =
    ( "session",
      [
        test_case "test anonymous request return cookie" `Quick
          test_anonymous_request_returns_cookie;
        test_case "test requests persist session variable" `Quick
          test_requests_persist_session_variables;
      ] )
end
