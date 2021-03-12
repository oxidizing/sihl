open Lwt.Syntax
open Alcotest_lwt

module Make (TokenService : Sihl.Contract.Token.Sig) = struct
  let create_and_read_token _ () =
    let* () = Sihl.Cleaner.clean_all () in
    let* token = TokenService.create [ "foo", "bar"; "fooz", "baz" ] in
    let* value = TokenService.read token ~k:"foo" in
    Alcotest.(check (option string) "reads value" (Some "bar") value);
    let* is_valid_signature = TokenService.verify token in
    Alcotest.(check bool "has valid signature" true is_valid_signature);
    let* is_active = TokenService.is_active token in
    Alcotest.(check bool "is active" true is_active);
    let* is_expired = TokenService.is_expired token in
    Alcotest.(check bool "is not expired" false is_expired);
    let* is_valid = TokenService.is_valid token in
    Alcotest.(check bool "is valid" true is_valid);
    Lwt.return ()
  ;;

  let deactivate_and_reactivate_token _ () =
    let* () = Sihl.Cleaner.clean_all () in
    let* token = TokenService.create [ "foo", "bar" ] in
    let* value = TokenService.read token ~k:"foo" in
    Alcotest.(check (option string) "reads value" (Some "bar") value);
    let* () = TokenService.deactivate token in
    let* value = TokenService.read token ~k:"foo" in
    Alcotest.(check (option string) "reads no value" None value);
    let* value = TokenService.read ~force:() token ~k:"foo" in
    Alcotest.(check (option string) "force reads value" (Some "bar") value);
    let* () = TokenService.activate token in
    let* value = TokenService.read token ~k:"foo" in
    Alcotest.(check (option string) "reads value again" (Some "bar") value);
    Lwt.return ()
  ;;

  let forge_token _ () =
    let* () = Sihl.Cleaner.clean_all () in
    let* token = TokenService.create [ "foo", "bar" ] in
    let* value = TokenService.read token ~k:"foo" in
    Alcotest.(check (option string) "reads value" (Some "bar") value);
    let forged_token = "prefix" ^ token in
    let* value = TokenService.read forged_token ~k:"foo" in
    Alcotest.(check (option string) "reads no value" None value);
    let* value = TokenService.read ~force:() forged_token ~k:"foo" in
    Alcotest.(check (option string) "force doesn't read value" None value);
    let* is_valid_signature = TokenService.verify forged_token in
    Alcotest.(check bool "signature is not valid" false is_valid_signature);
    Lwt.return ()
  ;;

  module Web = struct
    let find_user id =
      if String.equal id "1"
      then
        Lwt.return
        @@ Some
             Sihl.Contract.User.
               { id = "1"
               ; email = "foo@example.com"
               ; username = None
               ; password = "123123"
               ; status = "active"
               ; admin = false
               ; confirmed = false
               ; created_at = Ptime_clock.now ()
               ; updated_at = Ptime_clock.now ()
               }
      else failwith "Invalid user id provided"
    ;;

    let apply_middlewares handler find_user =
      handler
      |> Rock.Middleware.apply
           (TokenService.Web.Middleware.user ~key:"user_id" find_user)
      |> Rock.Middleware.apply Sihl.Web.Middleware.bearer_token
    ;;

    let bearer_token_fetch_user _ () =
      let* () = Sihl.Cleaner.clean_all () in
      let* token = TokenService.create [ "user_id", "1" ] in
      let token_header = Format.sprintf "Bearer %s" token in
      let req =
        Opium.Request.get "/some/path/login"
        |> Opium.Request.add_header ("authorization", token_header)
      in
      let handler req =
        let user = TokenService.Web.User.find req in
        let email = user.email in
        Alcotest.(check string "has same email" "foo@example.com" email);
        Lwt.return @@ Opium.Response.of_plain_text ""
      in
      let wrapped_handler = apply_middlewares handler find_user in
      let* _ = wrapped_handler req in
      Lwt.return ()
    ;;
  end

  let suite =
    [ ( "token"
      , [ test_case "create and find token" `Quick create_and_read_token
        ; test_case
            "deactivate and re-activate token"
            `Quick
            deactivate_and_reactivate_token
        ; test_case "forge token" `Quick forge_token
        ] )
    ; ( "web user"
      , [ test_case "bearer token fetch user" `Quick Web.bearer_token_fetch_user
        ] )
    ]
  ;;
end
