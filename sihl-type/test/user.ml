let validate_valid_password _ () =
  let password = "CD&*BA8txf3mRuGF" in
  let actual =
    Sihl_type.User.validate_new_password
      ~password
      ~password_confirmation:password
      ~password_policy:Sihl_type.User.default_password_policy
  in
  Alcotest.(check (result unit string) "is valid" (Ok ()) actual);
  Lwt.return ()
;;

let validate_invalid_password _ () =
  let password = "123" in
  let actual =
    Sihl_type.User.validate_new_password
      ~password
      ~password_confirmation:password
      ~password_policy:Sihl_type.User.default_password_policy
  in
  Alcotest.(
    check
      (result unit string)
      "is invalid"
      (Error "Password has to contain at least 8 characters")
      actual);
  Lwt.return ()
;;

let suite =
  Alcotest_lwt.
    [ ( "user"
      , [ test_case "validate valid password" `Quick validate_valid_password
        ; test_case "validate invalid password" `Quick validate_invalid_password
        ] )
    ]
;;

let () =
  Unix.putenv "SIHL_ENV" "test";
  Lwt_main.run (Alcotest_lwt.run "user" suite)
;;
