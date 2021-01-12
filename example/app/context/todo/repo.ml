(* The repository hides dealing with the database.

   It is allowed to know the model and it contains serialization/deserialization
   of its types. Try to keep the queries small and simple and do some work in
   the service. Once you run into performance issues, move code from the service
   into the queries. This makes them harder to maintain though. *)

let status =
  let open Model in
  let encode m =
    match m with
    | Active -> Ok "active"
    | Done -> Ok "done"
  in
  let decode m =
    match m with
    | "active" -> Ok Active
    | "done" -> Ok Done
    | value -> Error ("Invalid status read: " ^ value)
  in
  Caqti_type.(custom ~encode ~decode string)
;;

let todo =
  let open Model in
  let encode m =
    Ok (m.id, (m.description, (m.status, (m.created_at, m.updated_at))))
  in
  let decode (id, (description, (status, (created_at, updated_at)))) =
    Ok { id; description; status; created_at; updated_at }
  in
  Caqti_type.(
    custom
      ~encode
      ~decode
      (tup2 string (tup2 string (tup2 status (tup2 ptime ptime)))))
;;

let find_request =
  Caqti_request.find
    Caqti_type.string
    todo
    {sql|
        SELECT
          uuid,
          description,
          status,
          created_at,
          updated_at
        FROM todos
        WHERE uuid = ?::uuid
        |sql}
;;

let find id =
  Sihl.Database.query (fun connection ->
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      Connection.find find_request id |> Lwt.map Sihl.Database.raise_error)
;;

let find_opt id =
  Sihl.Database.query (fun connection ->
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      Connection.find_opt find_request id |> Lwt.map Sihl.Database.raise_error)
;;

let filter_fragment =
  {sql|
        WHERE todos.description LIKE $1
          OR todos.status LIKE $1 |sql}
;;

let search_query =
  {sql|
        SELECT
          uuid,
          description,
          status,
          created_at,
          updated_at
        FROM todos |sql}
;;

let requests =
  Sihl.Database.prepare_requests search_query filter_fragment "id" todo
;;

let found_rows_request =
  Caqti_request.find
    ~oneshot:true
    Caqti_type.unit
    Caqti_type.int
    "SELECT COUNT(*) FROM todos"
;;

let search sort filter limit =
  let open Lwt.Syntax in
  Sihl.Database.query (fun connection ->
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let* result =
        Sihl.Database.run_request connection requests sort filter limit
      in
      let* amount =
        Connection.find found_rows_request () |> Lwt.map Result.get_ok
      in
      Lwt.return (result, amount))
;;

let insert_request =
  Caqti_request.exec
    todo
    {sql|
        INSERT INTO todos (
          uuid,
          description,
          status,
          created_at,
          updated_at
        ) VALUES (
          $1,
          $2,
          $3,
          $4,
          $5
        )
        |sql}
;;

let insert todo =
  Sihl.Database.query (fun connection ->
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      Connection.exec insert_request todo |> Lwt.map Sihl.Database.raise_error)
;;

let update_request =
  Caqti_request.exec
    todo
    {sql|
        UPDATE todos
        SET
          description = $2,
          status = $3,
          created_at = $4,
          updated_at = $5
        WHERE todos.uuid = $1::uuid
        |sql}
;;

let update todo =
  Sihl.Database.query (fun connection ->
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      Connection.exec update_request todo |> Lwt.map Sihl.Database.raise_error)
;;

let clean_request = Caqti_request.exec Caqti_type.unit "TRUNCATE TABLE todos;"

let clean () =
  Sihl.Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
      Connection.exec clean_request () |> Lwt.map Sihl.Database.raise_error)
;;
