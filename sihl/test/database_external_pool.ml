(* Tests for [Sihl.Database.use_external_pool]. Uses a stub [use] and a stub
   connection, so no database is needed. *)

(* Records the transaction calls the stub connection receives. *)
let connection_calls : string list ref = ref []
let record call = connection_calls := !connection_calls @ [ call ]

module Stub_connection : Caqti_lwt.CONNECTION = struct
  let unsupported name = failwith ("stub connection: " ^ name)

  module Response = struct
    type ('b, 'm) t = unit

    let returned_count _ = unsupported "returned_count"
    let affected_count _ = unsupported "affected_count"
    let exec _ = unsupported "exec"
    let find _ = unsupported "find"
    let find_opt _ = unsupported "find_opt"
    let fold _ _ _ = unsupported "fold"
    let fold_s _ _ _ = unsupported "fold_s"
    let iter_s _ _ = unsupported "iter_s"
    let to_stream _ = unsupported "to_stream"
  end

  let driver_info = Caqti_driver_info.dummy

  let dialect =
    (Caqti.Template.Dialect.create_unknown [@alert "-caqti_private"])
      ~purpose:`Dummy
      ()
  ;;

  let driver_connection = None
  let call ~f:_ _ _ = unsupported "call"
  let set_statement_timeout _ = unsupported "set_statement_timeout"

  let start () =
    record "start";
    Lwt.return_ok ()
  ;;

  let commit () =
    record "commit";
    Lwt.return_ok ()
  ;;

  let rollback () =
    record "rollback";
    Lwt.return_ok ()
  ;;

  let deallocate _ = unsupported "deallocate"
  let disconnect () = Lwt.return_unit
  let validate () = Lwt.return_true
  let check f = f true

  let exec _ _ =
    record "exec";
    Lwt.return_ok ()
  ;;

  let exec_with_affected_count _ _ = unsupported "exec_with_affected_count"
  let find _ _ = unsupported "find"
  let find_opt _ _ = unsupported "find_opt"
  let fold _ _ _ _ = unsupported "fold"
  let fold_s _ _ _ _ = unsupported "fold_s"
  let iter_s _ _ _ = unsupported "iter_s"
  let collect_list _ _ = unsupported "collect_list"
  let rev_collect_list _ _ = unsupported "rev_collect_list"
  let with_transaction _ = unsupported "with_transaction"
  let populate ~table:_ ~columns:_ _ _ = unsupported "populate"
end

let stub_connection : Caqti_lwt.connection = (module Stub_connection)

(* What the stub [use] saw. *)
let use_calls = ref 0
let use_results : (unit, Caqti_error.t) result list ref = ref []
let started = ref false
let stopped = ref false

let stub_pool : Sihl.Database.external_pool =
  { use =
      (fun f ->
        incr use_calls;
        let%lwt result = f stub_connection in
        (* Keep the error value itself so tests can check it is unchanged. *)
        use_results := !use_results @ [ Result.map (fun _ -> ()) result ];
        Lwt.return result)
  ; start =
      (fun () ->
        started := true;
        Lwt.return_unit)
  ; stop =
      (fun () ->
        stopped := true;
        Lwt.return_unit)
  }
;;

let reset () =
  connection_calls := [];
  use_calls := 0;
  use_results := []
;;

let lost_connection : Caqti_error.t =
  (Caqti_error.connect_failed
     ~uri:(Uri.of_string "stub://db")
     (Caqti_error.Msg "connection lost")
    :> Caqti_error.t)
;;

let request : (unit, unit, [ `Zero ]) Caqti_request.t =
  let open Caqti_request.Infix in
  "SELECT 1" |> Caqti_type.(unit ->. unit)
;;

let fails_with_database_exception f =
  Lwt.catch
    (fun () ->
       let%lwt _ = f () in
       Lwt.return false)
    (function
      | Sihl.Contract.Database.Exception _ -> Lwt.return true
      | exn -> Lwt.fail exn)
;;

let calls = Alcotest.(list string)

let check_error_reached_use () =
  match !use_results with
  | [ Error error ] ->
    Alcotest.(check bool)
      "use receives the statement's error unchanged"
      true
      (error == lost_connection)
  | _ -> Alcotest.fail "expected exactly one Error result in use"
;;

let start_and_stop_call_hook _ () =
  let%lwt () = Sihl.Database.start () in
  Alcotest.(check bool) "start calls the hook" true !started;
  let%lwt () = Sihl.Database.stop () in
  Alcotest.(check bool) "stop calls the hook" true !stopped;
  Lwt.return ()
;;

let query_ok_goes_through_use _ () =
  reset ();
  let%lwt () = Sihl.Database.exec request () in
  let%lwt value = Sihl.Database.query' (fun _ -> Lwt.return_ok "value") in
  Alcotest.(check string) "query' result" "value" value;
  let%lwt value = Sihl.Database.query (fun _ -> Lwt.return 42) in
  Alcotest.(check int) "query result" 42 value;
  Alcotest.(check int) "use called per statement" 3 !use_calls;
  Alcotest.(check calls) "statement ran" [ "exec" ] !connection_calls;
  Lwt.return ()
;;

let query_error_reaches_use_unchanged _ () =
  reset ();
  let%lwt failed =
    fails_with_database_exception (fun () ->
      Sihl.Database.query' (fun _ -> Lwt.return_error lost_connection))
  in
  Alcotest.(check bool) "caller gets Exception" true failed;
  check_error_reached_use ();
  Lwt.return ()
;;

let ctx_pool_is_ignored _ () =
  reset ();
  let%lwt () = Sihl.Database.exec ~ctx:[ "pool", "unknown" ] request () in
  Alcotest.(check int) "use called" 1 !use_calls;
  Lwt.return ()
;;

let transaction_commits _ () =
  reset ();
  let%lwt () =
    Sihl.Database.transaction' (fun connection ->
      let module C = (val connection : Caqti_lwt.CONNECTION) in
      C.exec request ())
  in
  Alcotest.(check int) "use called once" 1 !use_calls;
  Alcotest.(check calls)
    "start, statement, commit on the connection from use"
    [ "start"; "exec"; "commit" ]
    !connection_calls;
  Lwt.return ()
;;

let transaction_error_rolls_back _ () =
  reset ();
  let%lwt failed =
    fails_with_database_exception (fun () ->
      Sihl.Database.transaction' (fun _ -> Lwt.return_error lost_connection))
  in
  Alcotest.(check bool) "caller gets Exception" true failed;
  Alcotest.(check calls)
    "rolled back, not committed"
    [ "start"; "rollback" ]
    !connection_calls;
  check_error_reached_use ();
  Lwt.return ()
;;

let transaction_exception_rolls_back _ () =
  reset ();
  let%lwt raised =
    Lwt.catch
      (fun () ->
         let%lwt () = Sihl.Database.transaction (fun _ -> failwith "boom") in
         Lwt.return false)
      (function
        | Failure msg when String.equal msg "boom" -> Lwt.return true
        | exn -> Lwt.fail exn)
  in
  Alcotest.(check bool) "original exception propagates" true raised;
  Alcotest.(check calls) "rolled back" [ "start"; "rollback" ] !connection_calls;
  Lwt.return ()
;;

let pool_functions_raise _ () =
  Alcotest.check_raises
    "fetch_pool raises"
    (Sihl.Contract.Database.Exception
       "fetch_pool is not available while an external pool is in use \
        (use_external_pool)")
    (fun () -> ignore (Sihl.Database.fetch_pool ()));
  Alcotest.check_raises
    "add_pool raises"
    (Sihl.Contract.Database.Exception
       "add_pool is not available while an external pool is in use \
        (use_external_pool)")
    (fun () -> Sihl.Database.add_pool "foo" "postgres://unused");
  Lwt.return ()
;;

let suite =
  Alcotest_lwt.
    [ ( "external pool"
      , [ test_case
            "start and stop call the hook"
            `Quick
            start_and_stop_call_hook
        ; test_case "statements go through use" `Quick query_ok_goes_through_use
        ; test_case
            "statement error reaches use unchanged"
            `Quick
            query_error_reaches_use_unchanged
        ; test_case "ctx pool key is ignored" `Quick ctx_pool_is_ignored
        ; test_case "transaction commits" `Quick transaction_commits
        ; test_case
            "transaction error rolls back"
            `Quick
            transaction_error_rolls_back
        ; test_case
            "transaction exception rolls back"
            `Quick
            transaction_exception_rolls_back
        ; test_case "fetch_pool and add_pool raise" `Quick pool_functions_raise
        ] )
    ]
;;

let () =
  Unix.putenv "SIHL_ENV" "test";
  Sihl.Database.use_external_pool stub_pool;
  Lwt_main.run (Alcotest_lwt.run "database external pool" suite)
;;
