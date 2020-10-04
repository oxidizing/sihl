open Sihl.Utils.Regex

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
