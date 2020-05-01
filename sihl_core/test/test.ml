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
      ( "config",
        [
          test_case "validate string" `Quick
            Test_config.Schema.test_validate_string;
          test_case "validate existing required if string" `Quick
            Test_config.Schema.test_validate_existing_required_if_string;
          test_case "validate required if non-existing string fails" `Quick
            Test_config.Schema
            .test_validate_required_if_non_existing_string_fails;
          test_case "validate non-existing required if string" `Quick
            Test_config.Schema.test_validate_non_existing_required_if_string;
          test_case "validate string with choices" `Quick
            Test_config.Schema.test_validate_string_with_choices;
          test_case "validate string with choices fails" `Quick
            Test_config.Schema.test_validate_string_with_choices_fails;
          test_case "validate required string without default fails" `Quick
            Test_config.Schema
            .test_validate_required_string_without_default_fails;
          test_case "validate required string with default" `Quick
            Test_config.Schema.test_validate_string_with_default;
          test_case "validate bool" `Quick Test_config.Schema.test_validate_bool;
          test_case "validate bool fails" `Quick
            Test_config.Schema.test_validate_bool_fails;
          test_case "validate existing required if bool" `Quick
            Test_config.Schema.test_validate_existing_required_if_bool;
          test_case "validate existing required if bool fails" `Quick
            Test_config.Schema.test_validate_existing_required_if_bool_fails;
          test_case "validate int" `Quick Test_config.Schema.test_validate_int;
          test_case "validate int fails" `Quick
            Test_config.Schema.test_validate_int_fails;
          test_case "process valid config" `Quick
            Test_config.Schema.test_process_valid_config;
          test_case "process invalid config fails" `Quick
            Test_config.Schema.test_process_invalid_config_fails;
        ] );
      ("flash", [ test_case "rotate" `Quick Test_flash.test_rotate ]);
      ( "http",
        [
          test_case "require url encoded body" `Quick
            Test_http.test_require_url_encoded_body;
          test_case "require tuple url encoded body" `Quick
            Test_http.test_require_tuple_url_encoded_body;
        ] );
    ]
