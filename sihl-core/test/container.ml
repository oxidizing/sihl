module ServiceA : Sihl_core.Container.Service.Sig = struct
  let start ctx =
    print_endline "Starting module A";
    Lwt.return ctx
  ;;

  let stop _ = Lwt.return ()
  let lifecycle = Sihl_core.Container.Lifecycle.create ~start ~stop "a"
end

module ServiceB : Sihl_core.Container.Service.Sig = struct
  let start ctx =
    print_endline "Starting module B";
    Lwt.return ctx
  ;;

  let stop _ = Lwt.return ()

  let lifecycle =
    Sihl_core.Container.Lifecycle.create
      "b"
      ~start
      ~stop
      ~dependencies:[ ServiceA.lifecycle ]
  ;;
end

module ServiceC : Sihl_core.Container.Service.Sig = struct
  let start ctx =
    print_endline "Starting module C";
    Lwt.return ctx
  ;;

  let stop _ = Lwt.return ()

  let lifecycle =
    Sihl_core.Container.Lifecycle.create
      "c"
      ~start
      ~stop
      ~dependencies:[ ServiceB.lifecycle ]
  ;;
end

module ServiceD : Sihl_core.Container.Service.Sig = struct
  let start ctx =
    print_endline "Starting module D";
    Lwt.return ctx
  ;;

  let stop _ = Lwt.return ()

  let lifecycle =
    Sihl_core.Container.Lifecycle.create
      "d"
      ~start
      ~stop
      ~dependencies:[ ServiceB.lifecycle; ServiceC.lifecycle ]
  ;;
end

let order_all_dependencies () =
  let expected = [ "a"; "b"; "c"; "d" ] in
  let actual =
    Sihl_core.Container.top_sort_lifecycles [ ServiceD.lifecycle ]
    |> List.map Sihl_core.Container.Lifecycle.name
  in
  Alcotest.(check (list string) "calculates dependencies" expected actual)
;;

let order_simple_dependency_list () =
  let expected = [ "a"; "b" ] in
  let actual =
    Sihl_core.Container.top_sort_lifecycles [ ServiceB.lifecycle ]
    |> List.map Sihl_core.Container.Lifecycle.name
  in
  Alcotest.(check (list string) "calculates dependencies" expected actual)
;;

let suite =
  Alcotest.
    [ ( "service container"
      , [ test_case "order all dependencies" `Quick order_all_dependencies
        ; test_case "order simple dependency list" `Quick order_simple_dependency_list
        ] )
    ]
;;

let () =
  Unix.putenv "SIHL_ENV" "test";
  Alcotest.run "container" suite
;;
