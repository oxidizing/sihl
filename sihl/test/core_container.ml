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

module ServiceE1 : Sihl.Container.Service.Sig = struct
  let start ctx =
    print_endline "Starting module E1";
    Lwt.return ctx
  ;;

  let stop _ = Lwt.return ()

  let lifecycle =
    Sihl.Container.create_lifecycle
      "e"
      ~implementation_name:"e1"
      ~start
      ~stop
      ~dependencies:(fun () -> [ ServiceB.lifecycle; ServiceC.lifecycle ])
  ;;
end

module ServiceE2 : Sihl.Container.Service.Sig = struct
  let start ctx =
    print_endline "Starting module E2";
    Lwt.return ctx
  ;;

  let stop _ = Lwt.return ()

  let lifecycle =
    Sihl.Container.create_lifecycle
      "e"
      ~implementation_name:"e2"
      ~start
      ~stop
      ~dependencies:(fun () -> [ ServiceE1.lifecycle ])
  ;;
end

let order_all_dependencies () =
  let expected = [ "a"; "b"; "c"; "d" ] in
  let actual =
    Sihl.Container.top_sort_lifecycles [ ServiceD.lifecycle ]
    |> List.map (fun lifecycle -> lifecycle.Sihl.Container.type_name)
  in
  Alcotest.(check (list string) "calculates dependencies" expected actual)
;;

let order_simple_dependency_list () =
  let expected = [ "a"; "b" ] in
  let actual =
    Sihl.Container.top_sort_lifecycles [ ServiceB.lifecycle ]
    |> List.map (fun lifecycle -> lifecycle.Sihl.Container.type_name)
  in
  Alcotest.(check (list string) "calculates dependencies" expected actual)
;;

let order_multi_type_name_dependencies () =
  let expected_type_name = [ "a"; "b"; "c"; "e"; "e" ] in
  let expected_impl_name = [ "a"; "b"; "c"; "e1"; "e2" ] in
  let actual =
    Sihl.Container.top_sort_lifecycles
      [ ServiceE1.lifecycle; ServiceE2.lifecycle ]
  in
  Alcotest.(
    check
      (list string)
      "calculates dependencies type name"
      expected_type_name
      (actual |> List.map (fun lifecycle -> lifecycle.Sihl.Container.type_name)));
  Alcotest.(
    check
      (list string)
      "calculates dependencies impl name"
      expected_impl_name
      (actual
      |> List.map (fun lifecycle ->
             lifecycle.Sihl.Container.implementation_name)))
;;

let suite =
  Alcotest.
    [ ( "service container"
      , [ test_case "order all dependencies" `Quick order_all_dependencies
        ; test_case
            "order simple dependency list"
            `Quick
            order_simple_dependency_list
        ; test_case
            "order multi type name dependencies"
            `Quick
            order_multi_type_name_dependencies
        ] )
    ]
;;

let () =
  Unix.putenv "SIHL_ENV" "test";
  Alcotest.run "container" suite
;;
