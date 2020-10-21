open Alcotest_lwt

let suite =
  [ ( "service context"
    , [ test_case "unique keys" `Quick Core_ctx.unique_keys
      ; test_case "replace value" `Quick Core_ctx.replace_value
      ; test_case "atomic" `Quick Core_ctx.atomic
      ] )
  ; ( "service container"
    , [ test_case "order all dependencies" `Quick Core_container.order_all_dependencies
      ; test_case
          "order simple dependency list"
          `Quick
          Core_container.order_simple_dependency_list
      ] )
  ; ( "service configuration"
    , [ test_case "read empty" `Quick Core_configuration.read_empty_value
      ; test_case "read non-existing" `Quick Core_configuration.read_non_existing
      ; test_case "read existing" `Quick Core_configuration.read_existing
      ; test_case "read schema invalid" `Quick Core_configuration.read_schema_invalid
      ; test_case "read schema" `Quick Core_configuration.read_schema
      ] )
  ; ( "http"
    , [ test_case "require url encoded body" `Quick Http.test_require_url_encoded_body
      ; test_case
          "require tuple url encoded body"
          `Quick
          Http.test_require_tuple_url_encoded_body
      ] )
  ; "web", [ test_case "prefix path" `Quick Web.externalize_link ]
  ; ( "query language"
    , [ test_case "to string limit offset" `Quick Ql.to_string_limit_offset
      ; test_case "to string sort" `Quick Ql.to_string_sort
      ; test_case "to string filter" `Quick Ql.to_string_filter
      ; test_case "to string" `Quick Ql.to_string
      ; test_case "to sql limit offset" `Quick Ql.to_sql_limit_offset
      ; test_case "to sql sort" `Quick Ql.to_sql_sort
      ; test_case "to sql filter" `Quick Ql.to_sql_filter
      ; test_case
          "to sql filter with partial whitelist"
          `Quick
          Ql.to_sql_filter_with_partial_whitelist
      ; test_case "to sql" `Quick Ql.to_sql
      ; test_case "to sql fragments" `Quick Ql.to_sql_fragments
      ; test_case "of string empty sort" `Quick Ql.of_string_empty_sort
      ; test_case "of string limit offset" `Quick Ql.of_string_limit_offset
      ; test_case "of string sort" `Quick Ql.of_string_sort
      ; test_case "of string filter" `Quick Ql.of_string_filter
      ; test_case "of string" `Quick Ql.of_string
      ] )
  ; ( "email"
    , [ test_case "render email simple" `Quick Email.test_email_rendering_simple
      ; test_case "render email complex" `Quick Email.test_email_rendering_complex
      ] )
  ; ( "regex"
    , [ test_case "extract" `Quick Regex.extract
      ; test_case "extract complex" `Quick Regex.extract_complex
      ; test_case "test 1" `Quick Regex.test1
      ; test_case "test 2" `Quick Regex.test2
      ; test_case "test 3" `Quick Regex.test3
      ] )
  ; ( "message"
    , [ test_case "entry to and from string" `Quick Message.entry_to_and_from_string
      ; test_case "rotate once" `Quick Message.rotate_once
      ; test_case "rotate twice" `Quick Message.rotate_twice
      ] )
  ; ( "session"
    , [ (* reenable once we have a in-memory implementation of the session repo *)
        (* test_case "session not expired" `Quick Test_session.session_not_expired;
         * test_case "test set session variable" `Quick
         *   Test_session.test_set_session_variable; *) ] )
  ; ( "jwt"
    , [ test_case "is not expired" `Quick Jwt.is_not_expired
      ; test_case "is expired" `Quick Jwt.is_expired
      ] )
  ; "queue", [ test_case "should job run" `Quick Queue.should_run_job ]
  ; ( "app"
    , [ test_case "run user command" `Quick Core_app.run_user_command
      ; test_case "run order command" `Quick Core_app.run_order_command
      ] )
  ]
;;

let () = Lwt_main.run (run "unit tests" suite)
