open Sihl.Core.Regex

let extract () =
  let regexp = of_string {|token=([\w|\-]*)|} in
  let actual = extract_last regexp "token=abc123" in
  let expected = Some "abc123" in
  Alcotest.(check (option string) "equals" expected actual)

let extract_complex () =
  let regexp = of_string {|token=([\w|\-]*)|} in
  let actual = extract_last regexp "foo token=abc123 bar" in
  let expected = Some "abc123" in
  Alcotest.(check (option string) "equals" expected actual)

let test1 () =
  let regexp = of_string {|token=([\w|\-]*)|} in
  Alcotest.(check bool "equals" true (test regexp "token=abc123"))

let test2 () =
  let regexp = of_string {|token=([\w|\-]*)|} in
  Alcotest.(check bool "equals" false (test regexp "token123"))

let test3 () =
  let regexp = of_string "Yes$|No$" in
  Alcotest.(check bool "equals" true (test regexp "Yes"))
