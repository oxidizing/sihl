open Sihl_core.Utils.Regex

let extract _ () =
  let regexp = of_string {|token=([\w|\-]*)|} in
  let actual = extract_last regexp "token=abc123" in
  let expected = Some "abc123" in
  Lwt.return @@ Alcotest.(check (option string) "equals" expected actual)
;;

let extract_complex _ () =
  let regexp = of_string {|token=([\w|\-]*)|} in
  let actual = extract_last regexp "foo token=abc123 bar" in
  let expected = Some "abc123" in
  Lwt.return @@ Alcotest.(check (option string) "equals" expected actual)
;;

let test1 _ () =
  let regexp = of_string {|token=([\w|\-]*)|} in
  Lwt.return @@ Alcotest.(check bool "equals" true (test regexp "token=abc123"))
;;

let test2 _ () =
  let regexp = of_string {|token=([\w|\-]*)|} in
  Lwt.return @@ Alcotest.(check bool "equals" false (test regexp "token123"))
;;

let test3 _ () =
  let regexp = of_string "Yes$|No$" in
  Lwt.return @@ Alcotest.(check bool "equals" true (test regexp "Yes"))
;;

let suite =
  Alcotest_lwt.
    [ ( "regex"
      , [ test_case "extract" `Quick extract
        ; test_case "extract complex" `Quick extract_complex
        ; test_case "test 1" `Quick test1
        ; test_case "test 2" `Quick test2
        ; test_case "test 3" `Quick test3
        ] )
    ]
;;

let () =
  Unix.putenv "SIHL_ENV" "test";
  Lwt_main.run (Alcotest_lwt.run "regex" suite)
;;
