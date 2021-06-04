let template =
  {|
open Lwt.Syntax

let testable_{{name}} =
  Alcotest.testable {{module}}.pp (fun t1 t2 ->
      String.equal t1.{{module}}.id t2.{{module}}.id)
;;

let create _ () =
  let* () = Sihl.Cleaner.clean_all () in
  let* () = {{module}}.clean () in
  let* created = {{module}}.create {{create_values}} |> Lwt.map Result.get_ok in
  let* (found : {{module}}.t) =
    {{module}}.find created.{{module}}.id |> Lwt.map Option.get
  in
  Alcotest.(check testable_{{name}} "is same" found created);
  Lwt.return ()
;;

let delete' _ () =
  let* () = Sihl.Cleaner.clean_all () in
  let* () = {{module}}.clean () in
  let* created = {{module}}.create {{create_values}} |> Lwt.map Result.get_ok in
  let* (found : {{module}}.t) =
    {{module}}.find created.{{module}}.id |> Lwt.map Option.get
  in
  let* _ = {{module}}.delete found in
  let* found =
    {{module}}.find created.{{module}}.id
  in
  Alcotest.(check bool "was deleted" true (Option.is_none found));
  Lwt.return ()
;;

let find_all _ () =
  let* () = Sihl.Cleaner.clean_all () in
  let* () = {{module}}.clean () in
  let* created1 = {{module}}.create {{create_values}} |> Lwt.map Result.get_ok in
  let* created2 = {{module}}.create {{create_values}} |> Lwt.map Result.get_ok in
  let* ({{name}}s : {{module}}.t list) = {{module}}.search () |> Lwt.map fst in
  Alcotest.(check (list testable_{{name}}) "has {{name}}s" [created2; created1] {{name}}s);
  Lwt.return ()
;;

let suite =
  Alcotest_lwt.
    [ ( "crud {{name}}"
      , [ test_case "create" `Quick create
        ; test_case "delete" `Quick delete'
        ; test_case "find_all" `Quick find_all
        ] )
    ]
;;

let services =
  [ Sihl.Database.register (); Service.Migration.register [] ]
;;

let () =
  let open Lwt.Syntax in
  Logs.set_level (Sihl.Log.get_log_level ());
  Logs.set_reporter (Sihl.Log.cli_reporter ());
  Lwt_main.run
    (let* _ = Sihl.Container.start_services services in
     let* () = Service.Migration.execute [ Database.{{module}}.migration ] in
     Alcotest_lwt.run "{{name}}" suite)
;;
|}
;;

let dune_file_template database =
  let open Gen_core in
  match database with
  | PostgreSql ->
    {|(test
        (name test)
        (libraries sihl service database alcotest alcotest-lwt
          caqti-driver-postgresql {{name}}))
|}
  | MariaDb ->
    {|(test
        (name test)
        (libraries sihl service database alcotest alcotest-lwt
          caqti-driver-mariadb {{name}}))
|}
;;

let create_values (schema : Gen_core.schema) =
  schema
  |> List.map snd
  |> List.map Gen_core.gen_type_to_example
  |> String.concat " "
;;

let test_file (name : string) (schema : Gen_core.schema) =
  let params =
    [ "name", name
    ; "module", CCString.capitalize_ascii name
    ; "create_values", create_values schema
    ]
  in
  Gen_core.{ name = "test.ml"; template; params }
;;

let dune_file (database : Gen_core.database) (name : string) =
  let params = [ "name", name ] in
  Gen_core.{ name = "dune"; template = dune_file_template database; params }
;;
