open Base

type t = Pcre.regexp

let of_string string = Pcre.regexp string

let test regexp string = Pcre.pmatch ~rex:regexp string

let extract_last regexp text =
  Pcre.extract_opt ~rex:regexp text
  |> Array.to_list |> List.tl |> Option.bind ~f:List.hd |> Option.join

module Internal_ = Pcre

(* Tests *)

let%test "extract" =
  let regexp = of_string {|token=([\w|\-]*)|} in
  let actual = extract_last regexp "token=abc123" in
  let expected = Some "abc123" in
  Option.equal String.equal actual expected

let%test "extract complex" =
  let regexp = of_string {|token=([\w|\-]*)|} in
  let actual = extract_last regexp "foo token=abc123 bar" in
  let expected = Some "abc123" in
  Option.equal String.equal actual expected

let%test "test 1" =
  let regexp = of_string {|token=([\w|\-]*)|} in
  test regexp "token=abc123"

let%test "test 2" =
  let regexp = of_string {|token=([\w|\-]*)|} in
  not @@ test regexp "token123"

let%test "test 3" =
  let regexp = of_string "Yes$|No$" in
  test regexp "Yes"
