open Alcotest_lwt
open Lwt.Syntax

module Make (SessionService : Sihl_contract.Session.Sig) = struct
  module FlashMiddleware = Sihl_web.Middleware.Flash.Make (SessionService)
  module SessionMiddleware = Sihl_web.Middleware.Session.Make (SessionService)

  let flash_middleware = FlashMiddleware.m ()
  let session_middleware = SessionMiddleware.m ()
  let middleware_stack = [ flash_middleware; session_middleware ]

  let wrap handler =
    List.fold_left
      (fun handler middleware -> Rock.Middleware.apply middleware handler)
      handler
      middleware_stack
  ;;

  let set_and_read_flash_message _ () =
    let* () = Sihl_persistence.Repository.clean_all () in
    let req = Sihl_type.Http_request.get "" in
    let* res =
      wrap
        (fun req ->
          let flash = Sihl_web.Middleware.Flash.find req in
          Alcotest.(check (option string) "has no flash content" None flash);
          let res = Sihl_type.Http_response.of_plain_text "" in
          let res = Sihl_web.Middleware.Flash.set (Some "foobar") res in
          Lwt.return res)
        req
    in
    (* we need to simulate the browser sending back the session cookie *)
    let cookie = Sihl_type.Http_response.cookie "sihl.session" res |> Option.get in
    let cookie_value = cookie.Opium.Cookie.value in
    let req = Sihl_type.Http_request.get "" in
    let req = Sihl_type.Http_request.add_cookie cookie_value req in
    let* _ =
      wrap
        (fun req ->
          let flash = Sihl_web.Middleware.Flash.find req in
          Alcotest.(check (option string) "has flash content" (Some "foobar") flash);
          let res = Sihl_type.Http_response.of_plain_text "" in
          let res = Sihl_web.Middleware.Flash.set (Some "nextfoo") res in
          Lwt.return res)
        req
    in
    let* _ =
      wrap
        (fun req ->
          let flash = Sihl_web.Middleware.Flash.find req in
          Alcotest.(check (option string) "has flash content" (Some "nextfoo") flash);
          let res = Sihl_type.Http_response.of_plain_text "" in
          Lwt.return res)
        req
    in
    let* _ =
      wrap
        (fun req ->
          let flash = Sihl_web.Middleware.Flash.find req in
          Alcotest.(check (option string) "has no flash content" None flash);
          let res = Sihl_type.Http_response.of_plain_text "" in
          Lwt.return res)
        req
    in
    let* sessions = SessionService.find_all () in
    Alcotest.(check int "Has created a session" 1 (List.length sessions));
    Lwt.return ()
  ;;

  let suite =
    [ ( "flash"
      , [ test_case "set and read flash message" `Quick set_and_read_flash_message ] )
    ]
  ;;
end
