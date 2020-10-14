open Lwt.Syntax

let fetch_pool _ () =
  let _ = Sihl.Database.Service.fetch_pool () in
  Lwt.return ()
;;

let drop_table_request =
  Caqti_request.exec Caqti_type.unit "DROP TABLE IF EXISTS testing_user"
;;

let drop_table_if_exists ctx =
  Sihl.Database.Service.query ctx (fun connection ->
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      Connection.exec drop_table_request ())
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

let create_table_if_not_exists ctx =
  Sihl.Database.Service.query ctx (fun connection ->
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      Connection.exec create_table_request ())
;;

let insert_username_request =
  Caqti_request.exec Caqti_type.string "INSERT INTO testing_user(username) VALUES (?)"
;;

let insert_username ctx username =
  Sihl.Database.Service.query ctx (fun connection ->
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      Connection.exec insert_username_request username)
;;

let get_usernames_request =
  Caqti_request.collect
    Caqti_type.unit
    Caqti_type.string
    "SELECT username FROM testing_user"
;;

let get_usernames ctx =
  Sihl.Database.Service.query ctx (fun connection ->
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      Connection.collect_list get_usernames_request ())
;;

let query_with_pool _ () =
  let ctx = Sihl.Core.Ctx.empty in
  let* () = drop_table_if_exists ctx in
  let* () = create_table_if_not_exists ctx in
  let* () = insert_username ctx "foobar pool" in
  let* usernames = get_usernames ctx in
  let username = List.hd usernames in
  Alcotest.(check string "has username" "foobar pool" username);
  Lwt.return ()
;;

let query_with_connection _ () =
  let ctx = Sihl.Core.Ctx.empty in
  let* () = drop_table_if_exists ctx in
  let* usernames =
    Sihl.Database.Service.with_connection ctx (fun ctx ->
        let* () = create_table_if_not_exists ctx in
        let* () = insert_username ctx "foobar connection" in
        get_usernames ctx)
  in
  let username = List.find (String.equal "foobar connection") usernames in
  Alcotest.(check string "has username" "foobar connection" username);
  Lwt.return ()
;;

let query_with_transaction _ () =
  let ctx = Sihl.Core.Ctx.empty in
  let* () = drop_table_if_exists ctx in
  let* usernames =
    Sihl.Database.Service.atomic ctx (fun ctx ->
        let* () = create_table_if_not_exists ctx in
        let* () = insert_username ctx "foobar trx" in
        get_usernames ctx)
  in
  let username = List.find (String.equal "foobar trx") usernames in
  Alcotest.(check string "has username" "foobar trx" username);
  Lwt.return ()
;;

let test_suite =
  ( "database"
  , [ Alcotest_lwt.test_case "fetch pool" `Quick fetch_pool
    ; Alcotest_lwt.test_case "query with pool" `Quick query_with_pool
    ; Alcotest_lwt.test_case "query with connection" `Quick query_with_connection
    ; Alcotest_lwt.test_case "query with transaction" `Quick query_with_transaction
    ] )
;;
