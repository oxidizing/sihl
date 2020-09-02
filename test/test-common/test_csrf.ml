open Alcotest_lwt
open Base
open Lwt.Syntax

(* TODO [aerben] FIX TESTS*)
module Make
    (DbService : Sihl.Data.Db.Sig.SERVICE)
    (RepoService : Sihl.Data.Repo.Sig.SERVICE)
    (TokenService : Sihl.Token.Sig.SERVICE)
    (SessionService : Sihl.Session.Sig.SERVICE)
    (Log : Sihl.Log.Sig.SERVICE) =
struct
  module Middleware =
    Sihl.Web.Middleware.Csrf.Make (TokenService) (Log) (SessionService)

  let get_request_yields_token _ () =
    let ctx =
      Sihl.Core.Ctx.empty |> DbService.add_pool
      |> Sihl.Web.Req.create_and_add_to_ctx
    in
    let* () = RepoService.clean_all ctx in
    let middleware = Middleware.m () in
    let handler ctx =
      let token = Sihl.Web.Middleware.Csrf.get_token ctx in
      let token_value =
        Option.value_exn (Option.map ~f:Sihl.Token.value token)
      in
      Alcotest.(
        check bool "Has CSRF token" true (not @@ String.is_empty token_value));
      Lwt.return @@ Sihl.Web.Res.html
    in
    let route = Sihl.Web.Route.all "/foo" handler in
    let wrapped_route = Sihl.Web.Middleware.apply middleware route in
    let* _ = Sihl.Web.Route.handler wrapped_route ctx in
    Lwt.return ()

  let get_request_without_token_succeeds _ () =
    let ctx =
      Sihl.Core.Ctx.empty |> DbService.add_pool
      |> Sihl.Web.Req.create_and_add_to_ctx
    in
    let* () = RepoService.clean_all ctx in
    let middleware = Middleware.m () in
    let handler _ = Lwt.return @@ Sihl.Web.Res.html in
    let route = Sihl.Web.Route.all "/foo" handler in
    let wrapped_route = Sihl.Web.Middleware.apply middleware route in
    let* response = Sihl.Web.Route.handler wrapped_route ctx in
    let status = Sihl.Web.Res.get_status response in
    Alcotest.(check int "Has status 200" 200 status);
    Lwt.return ()

  let post_request_yields_token _ () =
    let post_req =
      Opium.Std.Request.create
        ~body:(Cohttp_lwt.Body.of_string "")
        (Cohttp_lwt.Request.make ~meth:`POST (Uri.of_string "/foo"))
    in
    let ctx =
      Sihl.Core.Ctx.empty |> DbService.add_pool
      |> Sihl.Web.Req.add_to_ctx post_req
    in
    let* () = RepoService.clean_all ctx in
    let middleware = Middleware.m () in
    let handler ctx =
      let token = Sihl.Web.Middleware.Csrf.get_token ctx in
      let token_value =
        Option.value_exn (Option.map ~f:Sihl.Token.value token)
      in
      Alcotest.(
        check bool "Has CSRF token" true (not @@ String.is_empty token_value));
      Lwt.return @@ Sihl.Web.Res.html
    in
    let route = Sihl.Web.Route.all "/foo" handler in
    let wrapped_route = Sihl.Web.Middleware.apply middleware route in
    let* _ = Sihl.Web.Route.handler wrapped_route ctx in
    Lwt.return ()

  let post_request_without_token_fails _ () =
    let post_req =
      Opium.Std.Request.create
        (Cohttp_lwt.Request.make ~meth:`POST (Uri.of_string "/foo"))
    in
    let ctx =
      Sihl.Core.Ctx.empty |> DbService.add_pool
      |> Sihl.Web.Req.add_to_ctx post_req
    in
    let* () = RepoService.clean_all ctx in
    let middleware = Middleware.m () in
    let handler _ = Lwt.return @@ Sihl.Web.Res.html in
    let route = Sihl.Web.Route.all "/foo" handler in
    let wrapped_route = Sihl.Web.Middleware.apply middleware route in
    let* response = Sihl.Web.Route.handler wrapped_route ctx in
    let status = Sihl.Web.Res.get_status response in
    Alcotest.(check int "Has status 403" 403 status);
    Lwt.return ()

  let post_request_with_invalid_token_fails _ () =
    let post_req =
      Opium.Std.Request.create
        ~body:(Cohttp_lwt.Body.of_string "?csrf=invalid_token")
        (Cohttp_lwt.Request.make ~meth:`POST (Uri.of_string "/foo"))
    in
    let ctx =
      Sihl.Core.Ctx.empty |> DbService.add_pool
      |> Sihl.Web.Req.add_to_ctx post_req
    in
    let* () = RepoService.clean_all ctx in
    let middleware = Middleware.m () in
    let handler _ = Lwt.return @@ Sihl.Web.Res.html in
    let route = Sihl.Web.Route.all "/foo" handler in
    let wrapped_route = Sihl.Web.Middleware.apply middleware route in
    Lwt.catch
      (fun () -> Sihl.Web.Route.handler wrapped_route ctx |> Lwt.map ignore)
      (function
        | Sihl.Web.Middleware.Csrf.No_csrf_token txt ->
            Alcotest.(check string "Raises" "Invalid CSRF token" txt);
            Lwt.return ()
        | exn -> Lwt.fail exn)

  let post_request_with_valid_token_succeeds _ () =
    (* Do GET to set a token *)
    let ctx =
      Sihl.Core.Ctx.empty |> DbService.add_pool
      |> Sihl.Web.Req.create_and_add_to_ctx
    in
    let* () = RepoService.clean_all ctx in
    let middleware = Middleware.m () in
    let token_ref = ref "" in
    let handler ctx =
      let token = Sihl.Web.Middleware.Csrf.get_token ctx in
      let token_value =
        Option.value_exn (Option.map ~f:Sihl.Token.value token)
      in
      token_ref := token_value;
      Lwt.return Sihl.Web.Res.html
    in
    let route = Sihl.Web.Route.all "/foo" handler in
    let wrapped_route = Sihl.Web.Middleware.apply middleware route in
    let* response = Sihl.Web.Route.handler wrapped_route ctx in
    let status = Sihl.Web.Res.get_status response in
    Alcotest.(check int "Has status 200" 200 status);

    (* Do POST to use created token *)
    let body = Uri.pct_encode @@ "csrf=" ^ !token_ref in
    let post_req =
      Opium.Std.Request.create
        ~body:(Cohttp_lwt.Body.of_string body)
        (Cohttp_lwt.Request.make ~meth:`POST (Uri.of_string "/foo"))
    in
    let ctx =
      Sihl.Core.Ctx.empty |> DbService.add_pool
      |> Sihl.Web.Req.add_to_ctx post_req
    in
    let handler _ = Lwt.return Sihl.Web.Res.html in
    let route = Sihl.Web.Route.all "/foo" handler in
    let wrapped_route = Sihl.Web.Middleware.apply middleware route in
    let* response = Sihl.Web.Route.handler wrapped_route ctx in
    let status = Sihl.Web.Res.get_status response in
    Alcotest.(check int "Has status 200" 200 status);

    (* Check if token was invalidated*)
    let* token = TokenService.find ctx ~value:!token_ref () in
    Alcotest.(
      check Sihl.Token.Status.alco "Is token invalid" Inactive token.status);
    Lwt.return ()

  let test_suite =
    ( "csrf",
      [
        test_case "get request yields CSRF token" `Quick
          get_request_yields_token;
        test_case "get request without CSRF token succeeds" `Quick
          get_request_without_token_succeeds;
        test_case "post request yields CSRF token" `Quick
          post_request_yields_token;
        test_case "post request without CSRF token fails" `Quick
          post_request_without_token_fails;
        test_case "post request with invalid CSRF token fails" `Quick
          post_request_with_invalid_token_fails;
        test_case "post request with valid CSRF token succeeds" `Quick
          post_request_with_valid_token_succeeds;
      ] )
end
