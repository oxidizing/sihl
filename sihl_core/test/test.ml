let () =
  let open Alcotest in
  run "sihl core"
    [ ("email", [ test_case "email" `Quick Test_email.test_email_rendering ]) ]
