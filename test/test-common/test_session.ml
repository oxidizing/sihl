open Alcotest_lwt
open Base
open Lwt.Syntax

let middleware_stack ctx ?handler stack =
  let handler =
    Option.value ~default:(fun _ -> Lwt.return @@ Sihl.Web.Res.html) handler
  in
  let route = Sihl.Web.Route.get "" handler in
  let handler =
    Sihl.Web.Middleware.apply_stack stack route |> Sihl.Web.Route.handler
  in
  let ctx = Sihl.Web.Req.create_and_add_to_ctx ctx in
  handler ctx

module Make
    (DbService : Sihl.Data.Db.Service.Sig.SERVICE)
    (RepoService : Sihl.Data.Repo.Service.Sig.SERVICE)
    (SessionService : Sihl.Session.Service.Sig.SERVICE) =
struct
  module Middleware = Sihl.Web.Middleware.Session.Make (SessionService)

  let test_anonymous_request_returns_cookie _ () =
    let ctx = Sihl.Core.Ctx.empty |> DbService.add_pool in
    let* () = RepoService.clean_all ctx in
    let stack = [ Middleware.m () ] in
    let* _ = middleware_stack ctx stack in
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
    let* _ = middleware_stack ctx ~handler stack in
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
