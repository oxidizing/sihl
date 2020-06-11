open Base
open Sihl.Middleware.Flash

let entry_t = Alcotest.testable Entry.pp Entry.equal

let entry_to_and_from_string () =
  let actual = Entry.create (Error "foo") in
  let expected =
    actual |> Entry.to_string |> Entry.of_string |> Result.ok_or_failwith
  in
  Alcotest.(check entry_t "equals" expected actual)

let rotate_once () =
  let msg = Message.Success "foo" in
  let entry = Entry.create msg |> Entry.rotate in
  let is_current_set =
    entry |> Entry.current
    |> Option.map ~f:(Message.equal msg)
    |> Option.value ~default:false
  in
  let is_next_none = Option.is_none (entry |> Entry.next) in
  Alcotest.(check bool "is true" true (is_current_set && is_next_none))

let rotate_twice () =
  let actual = Entry.create (Success "foo") |> Entry.rotate |> Entry.rotate in
  Alcotest.(check entry_t "equals" Entry.empty actual)
