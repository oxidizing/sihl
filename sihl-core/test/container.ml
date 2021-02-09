module ServiceA : Sihl_core.Container.Service.Sig = struct
  let start ctx =
    print_endline "Starting module A";
    Lwt.return ctx
  ;;

  let stop _ = Lwt.return ()
  let lifecycle = Sihl_core.Container.create_lifecycle ~start ~stop "a"
end

module ServiceB : Sihl_core.Container.Service.Sig = struct
  let start ctx =
    print_endline "Starting module B";
    Lwt.return ctx
  ;;

  let stop _ = Lwt.return ()

  let lifecycle =
    Sihl_core.Container.create_lifecycle
      "b"
      ~start
      ~stop
      ~dependencies:(fun () -> [ ServiceA.lifecycle ])
  ;;
end

module ServiceC : Sihl_core.Container.Service.Sig = struct
  let start ctx =
    print_endline "Starting module C";
    Lwt.return ctx
  ;;

  let stop _ = Lwt.return ()

  let lifecycle =
    Sihl_core.Container.create_lifecycle
      "c"
      ~start
      ~stop
      ~dependencies:(fun () -> [ ServiceB.lifecycle ])
  ;;
end

module ServiceD : Sihl_core.Container.Service.Sig = struct
  let start ctx =
    print_endline "Starting module D";
    Lwt.return ctx
  ;;

  let stop _ = Lwt.return ()

  let lifecycle =
    Sihl_core.Container.create_lifecycle
      "d"
      ~start
      ~stop
      ~dependencies:(fun () -> [ ServiceB.lifecycle; ServiceC.lifecycle ])
  ;;
end

module ServiceE : Sihl_core.Container.Service.Sig = struct
  let start ctx =
    print_endline "Starting module E";
    Lwt.return ctx
  ;;

  let stop _ = Lwt.return ()

  let lifecycle =
    Sihl_core.Container.create_lifecycle
      "d"
      ~start
      ~stop
      ~dependencies:(fun () -> [ ServiceB.lifecycle; ServiceC.lifecycle ])
      ~implementation:"e"
  ;;
end

let order_all_dependencies () =
  let expected =
    [ "a.default"; "b.default"; "c.default"; "d.e"; "d.default" ]
  in
  let actual =
    Sihl_core.Container.top_sort_lifecycles
      [ ServiceD.lifecycle; ServiceE.lifecycle ]
    |> List.map Sihl_core.Container.build_name
  in
  Alcotest.(check (list string) "calculates dependencies" expected actual)
;;

let order_simple_dependency_list () =
  let expected = [ "a.default"; "b.default" ] in
  let actual =
    Sihl_core.Container.top_sort_lifecycles [ ServiceB.lifecycle ]
    |> List.map Sihl_core.Container.build_name
  in
  Alcotest.(check (list string) "calculates dependencies" expected actual)
;;

let suite =
  Alcotest.
    [ ( "service container"
      , [ test_case "order all dependencies" `Quick order_all_dependencies
        ; test_case
            "order simple dependency list"
            `Quick
            order_simple_dependency_list
        ] )
    ]
;;

let () =
  Unix.putenv "SIHL_ENV" "test";
  Logs.set_level (Sihl_core.Log.get_log_level ());
  Logs.set_reporter (Sihl_core.Log.cli_reporter ());
  Alcotest.run "container" suite
;;
