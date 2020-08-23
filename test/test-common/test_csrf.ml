open Alcotest_lwt
open Base
open Lwt.Syntax

module Make
    (DbService : Sihl.Data.Db.Sig.SERVICE)
    (RepoService : Sihl.Data.Repo.Sig.SERVICE)
    (TokenService : Sihl.Token.Sig.SERVICE)
    (Log : Sihl.Log.Sig.SERVICE) =
struct
  module Middleware = Sihl.Web.Middleware.Csrf.Make (TokenService) (Log)

  let get_request_yields_no_token _ () =
    let ctx = Sihl.Core.Ctx.empty |> DbService.add_pool in
    let* () = RepoService.clean_all ctx in
    let middleware = Middleware.m () in
    let handler ctx =
      let token = Sihl.Web.Middleware.Csrf.get_token ctx in
      Alcotest.(check (option Sihl.Token.alco) "Has no CSRF token" None token);
      Lwt.return @@ Sihl.Web.Res.html
    in
    let route = Sihl.Web.Route.get "" handler in
    let wrapped_route = Sihl.Web.Middleware.apply middleware route in
    let* _ = Sihl.Web.Route.handler wrapped_route ctx in
    Lwt.return ()

  let test_suite =
    ( "csrf",
      [
        test_case "get request yields no CSRF token" `Quick
          get_request_yields_no_token;
      ] )
end
