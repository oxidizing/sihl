module ServiceA : Sihl.Core.Container.SERVICE = struct
  let start ctx =
    print_endline "Starting module A";
    Lwt.return ctx

  let stop _ = Lwt.return ()

  let lifecycle = Sihl.Core.Container.Lifecycle.make ~start ~stop "a"
end

module ServiceB : Sihl.Core.Container.SERVICE = struct
  let start ctx =
    print_endline "Starting module B";
    Lwt.return ctx

  let stop _ = Lwt.return ()

  let lifecycle =
    Sihl.Core.Container.Lifecycle.make "b" ~start ~stop
      ~dependencies:[ ServiceA.lifecycle ]
end

module ServiceC : Sihl.Core.Container.SERVICE = struct
  let start ctx =
    print_endline "Starting module C";
    Lwt.return ctx

  let stop _ = Lwt.return ()

  let lifecycle =
    Sihl.Core.Container.Lifecycle.make "c" ~start ~stop
      ~dependencies:[ ServiceB.lifecycle ]
end

module ServiceD : Sihl.Core.Container.SERVICE = struct
  let start ctx =
    print_endline "Starting module D";
    Lwt.return ctx

  let stop _ = Lwt.return ()

  let lifecycle =
    Sihl.Core.Container.Lifecycle.make "d" ~start ~stop
      ~dependencies:[ ServiceB.lifecycle; ServiceC.lifecycle ]
end

let order_all_dependencies _ () =
  let services : (module Sihl.Core.Container.SERVICE) list =
    [ (module ServiceD) ]
  in
  let expected = [ "a"; "b"; "c"; "d" ] in
  let actual =
    services |> Sihl.Core.Container.top_sort_lifecycles
    |> List.map Sihl.Core.Container.Lifecycle.module_name
  in
  Alcotest.(check (list string) "calculates dependencies" expected actual);
  Lwt.return ()

let order_simple_dependency_list _ () =
  let services : (module Sihl.Core.Container.SERVICE) list =
    [ (module ServiceB) ]
  in
  let expected = [ "a"; "b" ] in
  let actual =
    services |> Sihl.Core.Container.top_sort_lifecycles
    |> List.map Sihl.Core.Container.Lifecycle.module_name
  in
  Alcotest.(check (list string) "calculates dependencies" expected actual);
  Lwt.return ()
