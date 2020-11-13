open Alcotest_lwt
open Lwt.Syntax

module Make (SessionService : Sihl.Session.Sig.SERVICE) = struct
  module Middleware = Sihl.Middleware.Session.Make (SessionService)

  let test_anonymous_request_returns_cookie _ () =
    let req = Sihl.Http.Request.get "" in
    let* () = Sihl.Repository.Service.clean_all () in
    let middleware = Middleware.m () in
    let* _ =
      Opium_kernel.Rock.Middleware.apply
        middleware
        (fun _ -> Lwt.return @@ Sihl.Http.Response.of_plain_text "")
        req
    in
    let* sessions = SessionService.find_all () in
    let () = Alcotest.(check int "Has created session" 1 (List.length sessions)) in
    Lwt.return ()
  ;;

  let test_requests_persist_session_variables _ () =
    let req = Sihl.Http.Request.get "" in
    let* () = Sihl.Repository.Service.clean_all () in
    let middleware = Middleware.m () in
    let handler req =
      let session = Sihl.Middleware.Session.find req in
      let* () = SessionService.set session ~key:"foo" ~value:"bar" in
      Lwt.return @@ Sihl.Http.Response.create ()
    in
    let* _ = Opium_kernel.Rock.Middleware.apply middleware handler req in
    let* session = SessionService.find_all () |> Lwt.map List.hd in
    let () =
      Alcotest.(
        check
          (option string)
          "Has created session with session value"
          (Some "bar")
          (Sihl.Session.get "foo" session))
    in
    Lwt.return ()
  ;;

  let test_suite =
    ( "session"
    , [ test_case
          "test anonymous request return cookie"
          `Quick
          test_anonymous_request_returns_cookie
      ; test_case
          "test requests persist session variable"
          `Quick
          test_requests_persist_session_variables
      ] )
  ;;
end
