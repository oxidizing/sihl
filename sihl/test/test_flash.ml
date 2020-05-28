open Base

let testable_message =
  (module Sihl.Middleware.Flash.Message : Alcotest.TESTABLE
    with type t = Sihl.Middleware.Flash.Message.t )

open Sihl.Middleware.Flash

let test_rotate () =
  let id = Uuidm.v `V4 |> Uuidm.to_string in
  let () = Store.add ~id (Error "some error happened") in
  let current = Store.find_current id in
  let () =
    Alcotest.(check @@ option testable_message)
      "current flash in None initially" None current
  in
  let () = Store.rotate id in
  let current = Store.find_current id in
  let () =
    Alcotest.(check @@ option testable_message)
      "current flash is set after rotation" (Some (Error "some error happened"))
      current
  in
  let () = Store.rotate id in
  let current = Store.find_current id in
  Alcotest.(check @@ option testable_message)
    "current flash is not set anymore after second rotation" None current
