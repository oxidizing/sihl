open Lwt.Syntax

let check_pool _ () =
  let _ = Sihl.Database.Service.fetch_pool () in
  Lwt.return ()
;;

let drop_table_request =
  Caqti_request.exec Caqti_type.unit "DROP TABLE IF EXISTS testing_user"
;;

let drop_table_if_exists connection =
  let module Connection = (val connection : Caqti_lwt.CONNECTION) in
  Connection.exec drop_table_request () |> Lwt.map Result.get_ok
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
  Connection.exec create_table_request () |> Lwt.map Result.get_ok
;;

let insert_username_request =
  Caqti_request.exec Caqti_type.string "INSERT INTO testing_user(username) VALUES (?)"
;;

let insert_username connection username =
  let module Connection = (val connection : Caqti_lwt.CONNECTION) in
  Connection.exec insert_username_request username |> Lwt.map Result.get_ok
;;

let get_usernames_request =
  Caqti_request.collect
    Caqti_type.unit
    Caqti_type.string
    "SELECT username FROM testing_user"
;;

let get_usernames connection =
  let module Connection = (val connection : Caqti_lwt.CONNECTION) in
  Connection.collect_list get_usernames_request () |> Lwt.map Result.get_ok
;;

let query _ () =
  let ctx = Sihl.Core.Ctx.create () in
  let* usernames =
    Sihl.Database.Service.query ctx (fun connection ->
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
  let ctx = Sihl.Core.Ctx.create () in
  let* usernames =
    Sihl.Database.Service.query ctx (fun connection ->
        let* () = drop_table_if_exists connection in
        let* () = create_table_if_not_exists connection in
        Sihl.Database.Service.transaction ctx (fun connection ->
            let* () = insert_username connection "foobar trx" in
            get_usernames connection))
  in
  let username = List.find (String.equal "foobar trx") usernames in
  Alcotest.(check string "has username" "foobar trx" username);
  Lwt.return ()
;;

let transaction_rolls_back _ () =
  let ctx = Sihl.Core.Ctx.create () in
  let* usernames =
    Sihl.Database.Service.query ctx (fun connection ->
        let* () = drop_table_if_exists connection in
        let* () = create_table_if_not_exists connection in
        let* () =
          Lwt.catch
            (fun () ->
              Sihl.Database.Service.transaction ctx (fun connection ->
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

let test_suite =
  ( "database"
  , [ Alcotest_lwt.test_case "fetch pool" `Quick check_pool
    ; Alcotest_lwt.test_case "query with pool" `Quick query
    ; Alcotest_lwt.test_case "query with transaction" `Quick query_with_transaction
    ; Alcotest_lwt.test_case "transaction rolls back" `Quick transaction_rolls_back
    ] )
;;
