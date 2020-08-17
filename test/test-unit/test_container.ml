module ServiceA : Sihl.Core.Container.SERVICE = struct
  let lifecycle =
    Sihl.Core.Container.Lifecycle.make "a"
      (fun ctx ->
        print_endline "Starting module A";
        Lwt.return ctx)
      (fun _ -> Lwt.return ())
end

module ServiceB : Sihl.Core.Container.SERVICE = struct
  let lifecycle =
    Sihl.Core.Container.Lifecycle.make "b" ~dependencies:[ ServiceA.lifecycle ]
      (fun ctx ->
        print_endline "Starting module B";
        Lwt.return ctx)
      (fun _ -> Lwt.return ())
end

module ServiceC : Sihl.Core.Container.SERVICE = struct
  let lifecycle =
    Sihl.Core.Container.Lifecycle.make "c" ~dependencies:[ ServiceB.lifecycle ]
      (fun ctx ->
        print_endline "Starting module C";
        Lwt.return ctx)
      (fun _ -> Lwt.return ())
end

module ServiceD : Sihl.Core.Container.SERVICE = struct
  let lifecycle =
    Sihl.Core.Container.Lifecycle.make "d"
      ~dependencies:[ ServiceB.lifecycle; ServiceC.lifecycle ]
      (fun ctx ->
        print_endline "Starting module D";
        Lwt.return ctx)
      (fun _ -> Lwt.return ())
end

let order_all_dependencies _ () =
  let services : (module Sihl.Core.Container.SERVICE) list =
    [ (module ServiceD) ]
  in
  let expected = [ "d"; "c"; "b"; "a" ] in
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
  let expected = [ "b"; "a" ] in
  let actual =
    services |> Sihl.Core.Container.top_sort_lifecycles
    |> List.map Sihl.Core.Container.Lifecycle.module_name
  in
  Alcotest.(check (list string) "calculates dependencies" expected actual);
  Lwt.return ()
