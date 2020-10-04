module Entry = Sihl.Message.Entry

let entry_t = Alcotest.testable Entry.pp Entry.equal

let entry_to_and_from_string _ () =
  let msg = Sihl.Message.empty |> Sihl.Message.set_error [ "foo" ] in
  let actual = Entry.create msg in
  let expected = actual |> Entry.to_string |> Entry.of_string |> Result.get_ok in
  Lwt.return @@ Alcotest.(check entry_t "equals" expected actual)
;;

let rotate_once _ () =
  let msg = Sihl.Message.empty |> Sihl.Message.set_success [ "foo" ] in
  let entry = Entry.create msg |> Entry.rotate in
  let is_current_set =
    entry
    |> Entry.current
    |> Option.map (Sihl.Message.equal msg)
    |> Option.value ~default:false
  in
  let is_next_none = Option.is_none (entry |> Entry.next) in
  Lwt.return @@ Alcotest.(check bool "is true" true (is_current_set && is_next_none))
;;

let rotate_twice _ () =
  let msg = Sihl.Message.empty |> Sihl.Message.set_success [ "foo" ] in
  let actual = Entry.create msg |> Entry.rotate |> Entry.rotate in
  Lwt.return @@ Alcotest.(check entry_t "equals" Entry.empty actual)
;;
