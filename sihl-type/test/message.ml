module Entry = Sihl_type.Message_entry

let entry_t = Alcotest.testable Entry.pp Entry.equal

let entry_to_and_from_string _ () =
  let msg = Sihl_type.Message.empty |> Sihl_type.Message.set_error [ "foo" ] in
  let actual = Entry.create msg in
  let expected = actual |> Entry.to_string |> Entry.of_string |> Result.get_ok in
  Lwt.return @@ Alcotest.(check entry_t "equals" expected actual)
;;

let rotate_once _ () =
  let msg = Sihl_type.Message.empty |> Sihl_type.Message.set_success [ "foo" ] in
  let entry = Entry.create msg |> Entry.rotate in
  let is_current_set =
    entry
    |> Entry.current
    |> Option.map (Sihl_type.Message.equal msg)
    |> Option.value ~default:false
  in
  let is_next_none = Option.is_none (entry |> Entry.next) in
  Lwt.return @@ Alcotest.(check bool "is true" true (is_current_set && is_next_none))
;;

let rotate_twice _ () =
  let msg = Sihl_type.Message.empty |> Sihl_type.Message.set_success [ "foo" ] in
  let actual = Entry.create msg |> Entry.rotate |> Entry.rotate in
  Lwt.return @@ Alcotest.(check entry_t "equals" Entry.empty actual)
;;

let suite =
  Alcotest_lwt.
    [ ( "message"
      , [ test_case "entry to and from string" `Quick entry_to_and_from_string
        ; test_case "rotate once" `Quick rotate_once
        ; test_case "rotate twice" `Quick rotate_twice
        ] )
    ]
;;

let () =
  Unix.putenv "SIHL_ENV" "test";
  Lwt_main.run (Alcotest_lwt.run "message" suite)
;;
