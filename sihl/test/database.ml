let check_pool _ () =
  let _ = Sihl.Database.fetch_pool () in
  Lwt.return ()
;;

let drop_table_request =
  let open Caqti_request.Infix in
  "DROP TABLE IF EXISTS testing_user" |> Caqti_type.(unit ->. unit)
;;

let drop_table_if_exists connection =
  let module Connection = (val connection : Caqti_lwt.CONNECTION) in
  Connection.exec drop_table_request () |> Lwt.map Sihl.Database.raise_error
;;

let create_table_request =
  let open Caqti_request.Infix in
  {sql|
    CREATE TABLE IF NOT EXISTS testing_user (
      username varchar(45) NOT NULL
    )
  |sql}
  |> Caqti_type.(unit ->. unit)
;;

let create_table_if_not_exists connection =
  let module Connection = (val connection : Caqti_lwt.CONNECTION) in
  Connection.exec create_table_request () |> Lwt.map Sihl.Database.raise_error
;;

let insert_username_request =
  let open Caqti_request.Infix in
  "INSERT INTO testing_user(username) VALUES (?)"
  |> Caqti_type.(string ->. unit)
;;

let insert_username connection username =
  let module Connection = (val connection : Caqti_lwt.CONNECTION) in
  Connection.exec insert_username_request username
  |> Lwt.map Sihl.Database.raise_error
;;

let get_usernames_request =
  let open Caqti_request.Infix in
  "SELECT username FROM testing_user" |> Caqti_type.(unit ->* string)
;;

let get_usernames connection =
  let module Connection = (val connection : Caqti_lwt.CONNECTION) in
  Connection.collect_list get_usernames_request ()
  |> Lwt.map Sihl.Database.raise_error
;;

let query _ () =
  let%lwt usernames =
    Sihl.Database.query (fun connection ->
      let%lwt () = drop_table_if_exists connection in
      let%lwt () = create_table_if_not_exists connection in
      let%lwt () = insert_username connection "foobar pool" in
      get_usernames connection)
  in
  let username = List.hd usernames in
  Alcotest.(check string "has username" "foobar pool" username);
  Lwt.return ()
;;

let query_with_transaction _ () =
  let%lwt usernames =
    Sihl.Database.query (fun connection ->
      let%lwt () = drop_table_if_exists connection in
      let%lwt () = create_table_if_not_exists connection in
      Sihl.Database.transaction (fun connection ->
        let%lwt () = insert_username connection "foobar trx" in
        get_usernames connection))
  in
  let username = List.find (String.equal "foobar trx") usernames in
  Alcotest.(check string "has username" "foobar trx" username);
  Lwt.return ()
;;

let transaction_rolls_back _ () =
  let%lwt usernames =
    Sihl.Database.query (fun connection ->
      let%lwt () = drop_table_if_exists connection in
      let%lwt () = create_table_if_not_exists connection in
      let%lwt () =
        Lwt.catch
          (fun () ->
             Sihl.Database.transaction (fun connection ->
               let%lwt () = insert_username connection "foobar trx" in
               failwith "Oh no, something went wrong during the transaction!"))
          (fun _ -> Lwt.return ())
      in
      get_usernames connection)
  in
  let username = List.find_opt (String.equal "foobar trx") usernames in
  Alcotest.(check (option string) "has no username" None username);
  Lwt.return ()
;;

let invalid_request =
  let open Caqti_request.Infix in
  "invalid query" |> Caqti_type.(unit ->. unit)
;;

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
      let%lwt () = Sihl.Database.query failing_query in
      loop (n - 1)
  in
  let%lwt () = loop 100 in
  Alcotest.(check bool "doesn't exhaust pool" true true);
  Lwt.return ()
;;

let transaction_does_not_exhaust_pool _ () =
  let rec loop n =
    match n with
    | 0 -> Lwt.return ()
    | n ->
      let%lwt () = Sihl.Database.transaction failing_query in
      loop (n - 1)
  in
  let%lwt () = loop 100 in
  Alcotest.(check bool "doesn't exhaust pool" true true);
  Lwt.return ()
;;

let choose_database_pool _ () =
  let default_pool = Sihl.Database.fetch_pool () in
  (* make sure there is no default database pool *)
  let%lwt () = Caqti_lwt_unix.Pool.drain default_pool in
  let database_url =
    Option.value
      ~default:"not found"
      (Sihl.Configuration.read_string "DATABASE_URL")
  in
  let () = Sihl.Database.add_pool "foo" database_url in
  let () = Sihl.Database.add_pool "bar" database_url in
  let ctx = [ "pool", "foo" ] in
  let%lwt usernames =
    Sihl.Database.query ~ctx (fun connection ->
      let%lwt () = drop_table_if_exists connection in
      let%lwt () = create_table_if_not_exists connection in
      let%lwt () = insert_username connection "some username" in
      get_usernames connection)
  in
  let username = List.hd usernames in
  Alcotest.(check string "has username" "some username" username);
  Lwt.return ()
;;

let drop_database_pool _ () =
  let open Sihl.Database in
  let%lwt () = fetch_pool () |> Caqti_lwt_unix.Pool.drain in
  let database_url =
    Option.value
      ~default:"not found"
      (Sihl.Configuration.read_string "DATABASE_URL")
  in
  let label = "foo" in
  let ctx = [ "pool", label ] in
  let%lwt check_connection =
    try
      (* Best indicator in Sihl at the moment is to check if "Database already
         exists" is raised when "drop_pool" didn't work. An unknown pool name
         results in running the query on the main database. *)
      let%lwt () = drop_pool label in
      let () = add_pool label database_url in
      let%lwt () = query ~ctx drop_table_if_exists in
      let%lwt () = drop_pool label in
      let () = add_pool label database_url in
      query ~ctx drop_table_if_exists |> Lwt_result.ok
    with
    | msg -> Printexc.to_string msg |> Lwt.return_error
  in
  Alcotest.(
    check (result unit string) "dropping table worked" (Ok ()) check_connection);
  Lwt.return_unit
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
        ; test_case "choose database pool" `Quick choose_database_pool
        ; test_case "drop database pool" `Quick drop_database_pool
        ] )
    ]
;;
