open Alcotest_lwt
open Lwt.Syntax

module Make (SessionService : Sihl_contract.Session.Sig) = struct
  module Middleware = Sihl_web.Middleware.Session.Make (SessionService)

  let test_anonymous_request_returns_cookie _ () =
    let req = Sihl_type.Http_request.get "" in
    let* () = Sihl_persistence.Repository.clean_all () in
    let middleware = Middleware.m () in
    let* _ =
      Opium_kernel.Rock.Middleware.apply
        middleware
        (fun _ -> Lwt.return @@ Sihl_type.Http_response.of_plain_text "")
        req
    in
    let* sessions = SessionService.find_all () in
    let () = Alcotest.(check int "Has created session" 1 (List.length sessions)) in
    Lwt.return ()
  ;;

  let test_requests_persist_session_variables _ () =
    let req = Sihl_type.Http_request.get "" in
    let* () = Sihl_persistence.Repository.clean_all () in
    let middleware = Middleware.m () in
    let handler req =
      let session = Sihl_web.Middleware.Session.find req in
      let* () = SessionService.set session ~key:"foo" ~value:"bar" in
      Lwt.return @@ Sihl_type.Http_response.create ()
    in
    let* _ = Opium_kernel.Rock.Middleware.apply middleware handler req in
    let* session = SessionService.find_all () |> Lwt.map List.hd in
    let () =
      Alcotest.(
        check
          (option string)
          "Has created session with session value"
          (Some "bar")
          (Sihl_type.Session.get "foo" session))
    in
    Lwt.return ()
  ;;

  let suite =
    [ ( "session"
      , [ test_case
            "test anonymous request return cookie"
            `Quick
            test_anonymous_request_returns_cookie
        ; test_case
            "test requests persist session variable"
            `Quick
            test_requests_persist_session_variables
        ] )
    ]
  ;;
end
