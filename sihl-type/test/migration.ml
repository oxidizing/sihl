module Map = Map.Make (String)

let migrations =
  [ Sihl_type.Migration.create_step ~label:"mig1" "some migs"
  ; Sihl_type.Migration.create_step ~label:"mig2" "some more migs"
  ; Sihl_type.Migration.create_step ~label:"mig3" "even more migs"
  ]
;;

let find_missing_migrations _ () =
  let migration_states =
    [ Sihl_type.Migration_state.create ~namespace:"Mathematicians"
    ; Sihl_type.Migration_state.create ~namespace:"Computer scientists"
    ; Sihl_type.Migration_state.create ~namespace:"Engineers"
    ]
  in
  let migrations =
    Map.empty |> Map.add "Mathematicians" migrations |> Map.add "Logicians" migrations
  in
  let status = Sihl_type.Migration.get_migrations_status migration_states migrations in
  let missing =
    List.filter_map
      (function
        | ns, None -> Some ns
        | _ -> None)
      status
  in
  Alcotest.(
    check
      (list string)
      "find missing migrations"
      missing
      [ "Computer scientists"; "Engineers" ]);
  Lwt.return ()
;;

let find_unapplied_migrations _ () =
  let migration_states =
    [ { (Sihl_type.Migration_state.create ~namespace:"Mathematicians") with version = 1 }
    ; { (Sihl_type.Migration_state.create ~namespace:"Logicians") with version = 3 }
    ; { (Sihl_type.Migration_state.create ~namespace:"Engineers") with version = 5 }
    ]
  in
  let migrations =
    Map.empty
    |> Map.add "Mathematicians" migrations
    |> Map.add "Logicians" migrations
    |> Map.add "Engineers" migrations
  in
  let status = Sihl_type.Migration.get_migrations_status migration_states migrations in
  Alcotest.(
    check
      (list string)
      "find unapplied migration names"
      (List.map fst status)
      [ "Mathematicians"; "Logicians"; "Engineers" ]);
  Alcotest.(
    check
      (list (option int))
      "find unapplied migration count"
      (List.map snd status)
      [ Some 2; Some 0; Some (-2) ]);
  Lwt.return ()
;;

let suite =
  Alcotest_lwt.
    [ ( "migration"
      , [ test_case "missing migrations" `Quick find_missing_migrations
        ; test_case "unapplied migrations" `Quick find_unapplied_migrations
        ] )
    ]
;;

let () =
  Unix.putenv "SIHL_ENV" "test";
  Lwt_main.run (Alcotest_lwt.run "migration" suite)
;;
