open Lwt.Syntax

let check_pool _ () =
  let _ = Sihl.Database.fetch_pool () in
  Lwt.return ()
;;

let drop_table_request =
  Caqti_request.exec Caqti_type.unit "DROP TABLE IF EXISTS testing_user"
;;

let drop_table_if_exists connection =
  let module Connection = (val connection : Caqti_lwt.CONNECTION) in
  Connection.exec drop_table_request () |> Lwt.map Sihl.Database.raise_error
;;

let create_table_request =
  Caqti_request.exec
    Caqti_type.unit
    {sql|
       CREATE TABLE IF NOT EXISTS testing_user (
         username varchar(45) NOT NULL
       )
       |sql}
;;

let create_table_if_not_exists connection =
  let module Connection = (val connection : Caqti_lwt.CONNECTION) in
  Connection.exec create_table_request () |> Lwt.map Sihl.Database.raise_error
;;

let insert_username_request =
  Caqti_request.exec
    Caqti_type.string
    "INSERT INTO testing_user(username) VALUES (?)"
;;

let insert_username connection username =
  let module Connection = (val connection : Caqti_lwt.CONNECTION) in
  Connection.exec insert_username_request username
  |> Lwt.map Sihl.Database.raise_error
;;

let get_usernames_request =
  Caqti_request.collect
    Caqti_type.unit
    Caqti_type.string
    "SELECT username FROM testing_user"
;;

let get_usernames connection =
  let module Connection = (val connection : Caqti_lwt.CONNECTION) in
  Connection.collect_list get_usernames_request ()
  |> Lwt.map Sihl.Database.raise_error
;;

let query _ () =
  let* usernames =
    Sihl.Database.query (fun connection ->
        let* () = drop_table_if_exists connection in
        let* () = create_table_if_not_exists connection in
        let* () = insert_username connection "foobar pool" in
        get_usernames connection)
  in
  let username = List.hd usernames in
  Alcotest.(check string "has username" "foobar pool" username);
  Lwt.return ()
;;

let query_with_transaction _ () =
  let* usernames =
    Sihl.Database.query (fun connection ->
        let* () = drop_table_if_exists connection in
        let* () = create_table_if_not_exists connection in
        Sihl.Database.transaction (fun connection ->
            let* () = insert_username connection "foobar trx" in
            get_usernames connection))
  in
  let username = List.find (String.equal "foobar trx") usernames in
  Alcotest.(check string "has username" "foobar trx" username);
  Lwt.return ()
;;

let transaction_rolls_back _ () =
  let* usernames =
    Sihl.Database.query (fun connection ->
        let* () = drop_table_if_exists connection in
        let* () = create_table_if_not_exists connection in
        let* () =
          Lwt.catch
            (fun () ->
              Sihl.Database.transaction (fun connection ->
                  let* () = insert_username connection "foobar trx" in
                  failwith "Oh no, something went wrong during the transaction!"))
            (fun _ -> Lwt.return ())
        in
        get_usernames connection)
  in
  let username = List.find_opt (String.equal "foobar trx") usernames in
  Alcotest.(check (option string) "has no username" None username);
  Lwt.return ()
;;

let invalid_request = Caqti_request.exec Caqti_type.unit "invalid query"

let failing_query connection =
  Lwt.catch
    (fun () ->
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      Connection.exec invalid_request () |> Lwt.map Sihl.Database.raise_error)
    (* eat the exception silently *)
      (fun _ -> Lwt.return ())
;;

let query_does_not_exhaust_pool _ () =
  let rec loop n =
    match n with
    | 0 -> Lwt.return ()
    | n ->
      let* () = Sihl.Database.query failing_query in
      loop (n - 1)
  in
  let* () = loop 100 in
  Alcotest.(check bool "doesn't exhaust pool" true true);
  Lwt.return ()
;;

let transaction_does_not_exhaust_pool _ () =
  let rec loop n =
    match n with
    | 0 -> Lwt.return ()
    | n ->
      let* () = Sihl.Database.transaction failing_query in
      loop (n - 1)
  in
  let* () = loop 100 in
  Alcotest.(check bool "doesn't exhaust pool" true true);
  Lwt.return ()
;;

let suite =
  Alcotest_lwt.
    [ ( "database"
      , [ test_case "fetch pool" `Quick check_pool
        ; test_case "query with pool" `Quick query
        ; test_case "query with transaction" `Quick query_with_transaction
        ; test_case "transaction rolls back" `Quick transaction_rolls_back
        ; test_case
            "failing function doesn't exhaust pool in query"
            `Quick
            query_does_not_exhaust_pool
        ; test_case
            "failing function doesn't exhaust pool in transaction"
            `Quick
            transaction_does_not_exhaust_pool
        ] )
    ]
;;
