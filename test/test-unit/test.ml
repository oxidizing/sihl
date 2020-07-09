open Alcotest_lwt

let suite =
  [
    ("config", []);
    ( "http",
      [
        test_case "require url encoded body" `Quick
          Test_http.test_require_url_encoded_body;
        test_case "require tuple url encoded body" `Quick
          Test_http.test_require_tuple_url_encoded_body;
      ] );
    ( "query language",
      [
        test_case "to string limit offset" `Quick Test_ql.to_string_limit_offset;
        test_case "to string sort" `Quick Test_ql.to_string_sort;
        test_case "to string filter" `Quick Test_ql.to_string_filter;
        test_case "to string" `Quick Test_ql.to_string;
        test_case "to sql limit offset" `Quick Test_ql.to_sql_limit_offset;
        test_case "to sql sort" `Quick Test_ql.to_sql_sort;
        test_case "to sql filter" `Quick Test_ql.to_sql_filter;
        test_case "to sql filter with partial whitelist" `Quick
          Test_ql.to_sql_filter_with_partial_whitelist;
        test_case "to sql" `Quick Test_ql.to_sql;
        test_case "to sql fragments" `Quick Test_ql.to_sql_fragments;
        test_case "of string empty sort" `Quick Test_ql.of_string_empty_sort;
        test_case "of string limit offset" `Quick Test_ql.of_string_limit_offset;
        test_case "of string sort" `Quick Test_ql.of_string_sort;
        test_case "of string filter" `Quick Test_ql.of_string_filter;
        test_case "of string" `Quick Test_ql.of_string;
      ] );
    ( "email",
      [
        test_case "render email simple" `Quick
          Test_email.test_email_rendering_simple;
        test_case "render email complex" `Quick
          Test_email.test_email_rendering_complex;
      ] );
    ( "regex",
      [
        test_case "extract" `Quick Test_regex.extract;
        test_case "extract complex" `Quick Test_regex.extract_complex;
        test_case "test 1" `Quick Test_regex.test1;
        test_case "test 2" `Quick Test_regex.test2;
        test_case "test 3" `Quick Test_regex.test3;
      ] );
    ( "message",
      [
        test_case "entry to and from string" `Quick
          Test_message.entry_to_and_from_string;
        test_case "rotate once" `Quick Test_message.rotate_once;
        test_case "rotate twice" `Quick Test_message.rotate_twice;
      ] );
    ( "session",
      [
        test_case "session not expired" `Quick Test_session.session_not_expired;
        test_case "test set session variable" `Quick
          Test_session.test_set_session_variable;
      ] );
  ]

let () = Lwt_main.run (run "unit tests" suite)
