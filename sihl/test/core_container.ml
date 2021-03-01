module ServiceA : Sihl.Container.Service.Sig = struct
  let start ctx =
    print_endline "Starting module A";
    Lwt.return ctx
  ;;

  let stop _ = Lwt.return ()
  let lifecycle = Sihl.Container.create_lifecycle ~start ~stop "a"
end

module ServiceB : Sihl.Container.Service.Sig = struct
  let start ctx =
    print_endline "Starting module B";
    Lwt.return ctx
  ;;

  let stop _ = Lwt.return ()

  let lifecycle =
    Sihl.Container.create_lifecycle "b" ~start ~stop ~dependencies:(fun () ->
        [ ServiceA.lifecycle ])
  ;;
end

module ServiceC : Sihl.Container.Service.Sig = struct
  let start ctx =
    print_endline "Starting module C";
    Lwt.return ctx
  ;;

  let stop _ = Lwt.return ()

  let lifecycle =
    Sihl.Container.create_lifecycle "c" ~start ~stop ~dependencies:(fun () ->
        [ ServiceB.lifecycle ])
  ;;
end

module ServiceD : Sihl.Container.Service.Sig = struct
  let start ctx =
    print_endline "Starting module D";
    Lwt.return ctx
  ;;

  let stop _ = Lwt.return ()

  let lifecycle =
    Sihl.Container.create_lifecycle "d" ~start ~stop ~dependencies:(fun () ->
        [ ServiceB.lifecycle; ServiceC.lifecycle ])
  ;;
end

let order_all_dependencies () =
  let expected = [ "a"; "b"; "c"; "d" ] in
  let actual =
    Sihl.Container.top_sort_lifecycles [ ServiceD.lifecycle ]
    |> List.map (fun lifecycle -> lifecycle.Sihl.Container.name)
  in
  Alcotest.(check (list string) "calculates dependencies" expected actual)
;;

let order_simple_dependency_list () =
  let expected = [ "a"; "b" ] in
  let actual =
    Sihl.Container.top_sort_lifecycles [ ServiceB.lifecycle ]
    |> List.map (fun lifecycle -> lifecycle.Sihl.Container.name)
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
  Alcotest.run "container" suite
;;
