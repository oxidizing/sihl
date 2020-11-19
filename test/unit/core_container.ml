module ServiceA : Sihl.Container.Service.Sig = struct
  let start ctx =
    print_endline "Starting module A";
    Lwt.return ctx
  ;;

  let stop _ = Lwt.return ()
  let lifecycle = Sihl.Container.Lifecycle.create ~start ~stop "a"
end

module ServiceB : Sihl.Container.Service.Sig = struct
  let start ctx =
    print_endline "Starting module B";
    Lwt.return ctx
  ;;

  let stop _ = Lwt.return ()

  let lifecycle =
    Sihl.Container.Lifecycle.create "b" ~start ~stop ~dependencies:[ ServiceA.lifecycle ]
  ;;
end

module ServiceC : Sihl.Container.Service.Sig = struct
  let start ctx =
    print_endline "Starting module C";
    Lwt.return ctx
  ;;

  let stop _ = Lwt.return ()

  let lifecycle =
    Sihl.Container.Lifecycle.create "c" ~start ~stop ~dependencies:[ ServiceB.lifecycle ]
  ;;
end

module ServiceD : Sihl.Container.Service.Sig = struct
  let start ctx =
    print_endline "Starting module D";
    Lwt.return ctx
  ;;

  let stop _ = Lwt.return ()

  let lifecycle =
    Sihl.Container.Lifecycle.create
      "d"
      ~start
      ~stop
      ~dependencies:[ ServiceB.lifecycle; ServiceC.lifecycle ]
  ;;
end

let order_all_dependencies _ () =
  let expected = [ "a"; "b"; "c"; "d" ] in
  let actual =
    Sihl.Container.top_sort_lifecycles [ ServiceD.lifecycle ]
    |> List.map Sihl.Container.Lifecycle.name
  in
  Alcotest.(check (list string) "calculates dependencies" expected actual);
  Lwt.return ()
;;

let order_simple_dependency_list _ () =
  let expected = [ "a"; "b" ] in
  let actual =
    Sihl.Container.top_sort_lifecycles [ ServiceB.lifecycle ]
    |> List.map Sihl.Container.Lifecycle.name
  in
  Alcotest.(check (list string) "calculates dependencies" expected actual);
  Lwt.return ()
;;
