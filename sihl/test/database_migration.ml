module Map = Map.Make (String)

let clean_state () =
  (* Clean database state, all tests create either of these tables *)
  Sihl.Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
    let open Lwt_result.Syntax in
    let open Caqti_request.Infix in
    let* () =
      "DROP TABLE IF EXISTS test_core_migration_state"
      |> Caqti_type.(unit ->. unit)
      |> CCFun.flip Connection.exec ()
    in
    let* () =
      "DROP TABLE IF EXISTS professions"
      |> Caqti_type.(unit ->. unit)
      |> CCFun.flip Connection.exec ()
    in
    "DROP TABLE IF EXISTS orders"
    |> Caqti_type.(unit ->. unit)
    |> CCFun.flip Connection.exec ())
  |> Lwt.map Sihl.Database.raise_error
;;

module Make (MigrationService : Sihl.Contract.Migration.Sig) = struct
  let run_migrations _ () =
    let open Caqti_request.Infix in
    let%lwt () = clean_state () in
    (* Use test migration state table to not interfere with other tests *)
    Sihl.Configuration.store
      [ "MIGRATION_STATE_TABLE", "test_core_migration_state" ];
    let%lwt () = MigrationService.lifecycle.stop () in
    let%lwt () = MigrationService.lifecycle.start () in
    let migration : Sihl.Database.Migration.t =
      ( "professions"
      , [ Sihl.Database.Migration.create_step
            ~label:"create table"
            "CREATE TABLE professions (salary INT)"
        ] )
    in
    let%lwt () = MigrationService.execute [ migration ] in
    let%lwt _ =
      (* If this doesn't fail, test is ok *)
      Sihl.Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
        "SELECT salary FROM professions"
        |> Caqti_type.(unit ->? int)
        |> CCFun.flip Connection.find_opt ())
      |> Lwt.map Sihl.Database.raise_error
    in
    Lwt.return ()
  ;;

  let pending_migrations _ () =
    let%lwt () = clean_state () in
    (* Use test migration state table to not interfere with other tests *)
    Sihl.Configuration.store
      [ "MIGRATION_STATE_TABLE", "test_core_migration_state" ];
    let%lwt () = MigrationService.lifecycle.stop () in
    let%lwt () = MigrationService.lifecycle.start () in
    let%lwt status = MigrationService.pending_migrations () in
    Alcotest.(check (list (pair string int)) "no pending migrations" [] status);
    let migration1 : Sihl.Database.Migration.t =
      ( "professions"
      , [ Sihl.Database.Migration.create_step
            ~label:"create professions table"
            "CREATE TABLE professions (salary INT)"
        ] )
    in
    MigrationService.register_migrations [ migration1 ];
    let%lwt status = MigrationService.pending_migrations () in
    Alcotest.(
      check
        (list (pair string int))
        "one pending migration"
        [ "professions", 1 ]
        status);
    let%lwt () = MigrationService.run_all () in
    let migration2 : Sihl.Database.Migration.t =
      ( "orders"
      , [ Sihl.Database.Migration.create_step
            ~label:"create orders table"
            "CREATE TABLE orders (amount INT)"
        ] )
    in
    MigrationService.register_migrations [ migration2 ];
    let%lwt status = MigrationService.pending_migrations () in
    Alcotest.(
      check
        (list (pair string int))
        "one pending migration"
        [ "orders", 1 ]
        status);
    let%lwt () = MigrationService.run_all () in
    let%lwt status = MigrationService.pending_migrations () in
    Alcotest.(check (list (pair string int)) "desired state reached" [] status);
    Lwt.return ()
  ;;

  let suite =
    Alcotest_lwt.
      [ ( "migration"
        , [ test_case "run migrations" `Quick run_migrations
          ; test_case "pending migrations" `Quick pending_migrations
          ] )
      ]
  ;;
end
