open Lwt.Syntax
open Alcotest_lwt

let create_and_read_token _ () =
  let* () = Sihl_core.Cleaner.clean_all () in
  let* token = Sihl_facade.Token.create [ "foo", "bar"; "fooz", "baz" ] in
  let* value = Sihl_facade.Token.read token ~k:"foo" in
  Alcotest.(check (option string) "reads value" (Some "bar") value);
  let* is_valid_signature = Sihl_facade.Token.verify token in
  Alcotest.(check bool "has valid signature" true is_valid_signature);
  let* is_active = Sihl_facade.Token.is_active token in
  Alcotest.(check bool "is active" true is_active);
  let* is_expired = Sihl_facade.Token.is_expired token in
  Alcotest.(check bool "is not expired" false is_expired);
  let* is_valid = Sihl_facade.Token.is_valid token in
  Alcotest.(check bool "is valid" true is_valid);
  Lwt.return ()
;;

let deactivate_and_reactivate_token _ () =
  let* () = Sihl_core.Cleaner.clean_all () in
  let* token = Sihl_facade.Token.create [ "foo", "bar" ] in
  let* value = Sihl_facade.Token.read token ~k:"foo" in
  Alcotest.(check (option string) "reads value" (Some "bar") value);
  let* () = Sihl_facade.Token.deactivate token in
  let* value = Sihl_facade.Token.read token ~k:"foo" in
  Alcotest.(check (option string) "reads no value" None value);
  let* value = Sihl_facade.Token.read ~force:() token ~k:"foo" in
  Alcotest.(check (option string) "force reads value" (Some "bar") value);
  let* () = Sihl_facade.Token.activate token in
  let* value = Sihl_facade.Token.read token ~k:"foo" in
  Alcotest.(check (option string) "reads value again" (Some "bar") value);
  Lwt.return ()
;;

let forge_token _ () =
  let* () = Sihl_core.Cleaner.clean_all () in
  let* token = Sihl_facade.Token.create [ "foo", "bar" ] in
  let* value = Sihl_facade.Token.read token ~k:"foo" in
  Alcotest.(check (option string) "reads value" (Some "bar") value);
  let forged_token = "prefix" ^ token in
  let* value = Sihl_facade.Token.read forged_token ~k:"foo" in
  Alcotest.(check (option string) "reads no value" None value);
  let* value = Sihl_facade.Token.read ~force:() forged_token ~k:"foo" in
  Alcotest.(check (option string) "force doesn't read value" None value);
  let* is_valid_signature = Sihl_facade.Token.verify forged_token in
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
