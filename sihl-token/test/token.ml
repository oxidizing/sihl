open Alcotest_lwt

module Make (TokenService : Sihl.Contract.Token.Sig) = struct
  let create_and_read_token _ () =
    let%lwt () = Sihl.Cleaner.clean_all () in
    let%lwt token = TokenService.create [ "foo", "bar"; "fooz", "baz" ] in
    let%lwt value = TokenService.read token ~k:"foo" in
    Alcotest.(check (option string) "reads value" (Some "bar") value);
    let%lwt is_valid_signature = TokenService.verify token in
    Alcotest.(check bool "has valid signature" true is_valid_signature);
    let%lwt is_active = TokenService.is_active token in
    Alcotest.(check bool "is active" true is_active);
    let%lwt is_expired = TokenService.is_expired token in
    Alcotest.(check bool "is not expired" false is_expired);
    let%lwt is_valid = TokenService.is_valid token in
    Alcotest.(check bool "is valid" true is_valid);
    Lwt.return ()
  ;;

  let deactivate_and_reactivate_token _ () =
    let%lwt () = Sihl.Cleaner.clean_all () in
    let%lwt token = TokenService.create [ "foo", "bar" ] in
    let%lwt value = TokenService.read token ~k:"foo" in
    Alcotest.(check (option string) "reads value" (Some "bar") value);
    let%lwt () = TokenService.deactivate token in
    let%lwt value = TokenService.read token ~k:"foo" in
    Alcotest.(check (option string) "reads no value" None value);
    let%lwt value = TokenService.read ~force:() token ~k:"foo" in
    Alcotest.(check (option string) "force reads value" (Some "bar") value);
    let%lwt () = TokenService.activate token in
    let%lwt value = TokenService.read token ~k:"foo" in
    Alcotest.(check (option string) "reads value again" (Some "bar") value);
    Lwt.return ()
  ;;

  let forge_token _ () =
    let%lwt () = Sihl.Cleaner.clean_all () in
    let%lwt token = TokenService.create [ "foo", "bar" ] in
    let%lwt value = TokenService.read token ~k:"foo" in
    Alcotest.(check (option string) "reads value" (Some "bar") value);
    let forged_token = "prefix" ^ token in
    let%lwt value = TokenService.read forged_token ~k:"foo" in
    Alcotest.(check (option string) "reads no value" None value);
    let%lwt value = TokenService.read ~force:() forged_token ~k:"foo" in
    Alcotest.(check (option string) "force doesn't read value" None value);
    let%lwt is_valid_signature = TokenService.verify forged_token in
    Alcotest.(check bool "signature is not valid" false is_valid_signature);
    Lwt.return ()
  ;;

  let suite =
    [ ( "token"
      , [ test_case "create and find token" `Quick create_and_read_token
        ; test_case
            "deactivate and re-activate token"
            `Quick
            deactivate_and_reactivate_token
        ; test_case "forge token" `Quick forge_token
        ] )
    ]
  ;;
end
