open Alcotest_lwt
open Lwt.Syntax

module Make (SessionService : Sihl_contract.Session.Sig) = struct
  module SessionMiddleware = Sihl_web.Middleware.Session.Make (SessionService)

  let multiple_requests_create_one_session _ () =
    let* () = Sihl_persistence.Repository.clean_all () in
    let middleware = SessionMiddleware.m () in
    let req = Sihl_type.Http_request.get "" in
    let* res =
      Rock.Middleware.apply
        middleware
        (fun _ -> Lwt.return @@ Sihl_type.Http_response.of_plain_text "")
        req
    in
    let* sessions = SessionService.find_all () in
    let session_value1 = sessions |> List.hd |> Sihl_type.Session.key in
    Alcotest.(check int "Has created a session" 1 (List.length sessions));
    let cookie = Sihl_type.Http_response.cookie "sihl.session" res |> Option.get in
    let cookie_value = cookie.Opium.Cookie.value in
    let* _ =
      Rock.Middleware.apply
        middleware
        (fun _ -> Lwt.return Sihl_type.Http_response.(of_plain_text ""))
        (Sihl_type.Http_request.add_cookie cookie_value req)
    in
    let* sessions = SessionService.find_all () in
    let session_value2 = sessions |> List.hd |> Sihl_type.Session.key in
    Alcotest.(check int "Has created just one session" 1 (List.length sessions));
    Alcotest.(check string "Same session reused" session_value1 session_value2);
    Lwt.return ()
  ;;

  let requests_persist_session_variables _ () =
    let* () = Sihl_persistence.Repository.clean_all () in
    let middleware = SessionMiddleware.m () in
    let req = Sihl_type.Http_request.get "" in
    let handler req =
      let session = Sihl_web.Middleware.Session.find req in
      let* () = SessionService.set_value session ~k:"foo" ~v:(Some "bar") in
      Lwt.return @@ Sihl_type.Http_response.of_plain_text ""
    in
    let* _ = Rock.Middleware.apply middleware handler req in
    let* session = SessionService.find_all () |> Lwt.map List.hd in
    let* value = SessionService.find_value session "foo" in
    Alcotest.(
      check (option string) "Has created session with session value" (Some "bar") value);
    Lwt.return ()
  ;;

  let suite =
    [ ( "session"
      , [ test_case
            "multiple requests create one session"
            `Quick
            multiple_requests_create_one_session
        ; test_case
            "requests persist session variable"
            `Quick
            requests_persist_session_variables
        ] )
    ]
  ;;
end
