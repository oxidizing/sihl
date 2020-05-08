let () =
  let open Alcotest in
  run "sihl core"
    [
      ( "email",
        [
          test_case "render email simple" `Quick
            Test_email.test_email_rendering_simple;
          test_case "render email complex" `Quick
            Test_email.test_email_rendering_complex;
        ] );
    ]
