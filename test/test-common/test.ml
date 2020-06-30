open Alcotest_lwt

let session =
  ( "session",
    [ (* test_case "test anonymous request return cookie" `Quick
       *   Test_session.test_anonymous_request_returns_cookie;
       * test_case "test requests persist session variable" `Quick
       *   Test_session.test_requests_persist_session_variables; *) ] )

let storage =
  ( "storage",
    [
      test_case "upload file" `Quick Test_storage.fetch_uploaded_file;
      test_case "update file" `Quick Test_storage.update_uploaded_file;
    ] )
