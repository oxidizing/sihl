module Map = Map.Make (String)

let status =
  let open Sihl.Contract.Queue in
  let to_string = function
    | Pending -> "pending"
    | Succeeded -> "succeeded"
    | Failed -> "failed"
    | Cancelled -> "cancelled"
  in
  let of_string str =
    match str with
    | "pending" -> Ok Pending
    | "succeeded" -> Ok Succeeded
    | "failed" -> Ok Failed
    | "cancelled" -> Ok Cancelled
    | _ -> Error (Printf.sprintf "Unexpected job status %s found" str)
  in
  let encode m = Ok (to_string m) in
  let decode = of_string in
  Caqti_type.(custom ~encode ~decode string)
;;

let job =
  let open Sihl.Contract.Queue in
  let encode m =
    Ok
      ( m.id
      , ( m.name
        , ( m.input
          , ( m.tries
            , ( m.next_run_at
              , (m.max_tries, (m.status, (m.last_error, m.last_error_at))) ) )
          ) ) )
  in
  let decode
      ( id
      , ( name
        , ( input
          , ( tries
            , (next_run_at, (max_tries, (status, (last_error, last_error_at))))
            ) ) ) )
    =
    Ok
      { id
      ; name
      ; input
      ; tries
      ; next_run_at
      ; max_tries
      ; status
      ; last_error
      ; last_error_at
      }
  in
  Caqti_type.(
    custom
      ~encode
      ~decode
      (tup2
         string
         (tup2
            string
            (tup2
               string
               (tup2
                  int
                  (tup2
                     ptime
                     (tup2
                        int
                        (tup2 status (tup2 (option string) (option ptime))))))))))
;;

module MakeMariaDb (MigrationService : Sihl.Contract.Migration.Sig) = struct
  let lifecycles = [ Sihl.Database.lifecycle; MigrationService.lifecycle ]

  let enqueue_request =
    Caqti_request.exec
      job
      {sql|
        INSERT INTO queue_jobs (
          uuid,
          name,
          input,
          tries,
          next_run_at,
          max_tries,
          status,
          last_error,
          last_error_at
        ) VALUES (
          UNHEX(REPLACE($1, '-', '')),
          $2,
          $3,
          $4,
          $5,
          $6,
          $7,
          $8,
          $9
        )
        |sql}
  ;;

  let enqueue job_instance =
    Sihl.Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec enqueue_request job_instance
        |> Lwt.map Sihl.Database.raise_error)
  ;;

  (* MariaDB expects uuid to be bytes, since we can't unhex when using caqti's
     populate, we have to do that manually. *)
  let populatable job_instances =
    job_instances
    |> List.map (fun j ->
           Sihl.Contract.Queue.
             { j with
               id = j.id |> Uuidm.of_string |> Option.get |> Uuidm.to_bytes
             })
  ;;

  let enqueue_all job_instances =
    Sihl.Database.transaction' (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.populate
          ~table:"queue_jobs"
          ~columns:
            [ "uuid"
            ; "name"
            ; "input"
            ; "tries"
            ; "next_run_at"
            ; "max_tries"
            ; "status"
            ; "last_error"
            ; "last_error_at"
            ]
          job
          (job_instances |> populatable |> List.rev |> Caqti_lwt.Stream.of_list)
        |> Lwt.map Caqti_error.uncongested)
  ;;

  let update_request =
    Caqti_request.exec
      job
      {sql|
        UPDATE queue_jobs
        SET
          name = $2,
          input = $3,
          tries = $4,
          next_run_at = $5,
          max_tries = $6,
          status = $7,
          last_error = $8,
          last_error_at = $9
        WHERE
          queue_jobs.uuid = UNHEX(REPLACE($1, '-', ''))
        |sql}
  ;;

  let update job_instance =
    Sihl.Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec update_request job_instance
        |> Lwt.map Sihl.Database.raise_error)
  ;;

  let find_workable_request =
    Caqti_request.collect
      Caqti_type.unit
      job
      {sql|
        SELECT
          LOWER(CONCAT(
           SUBSTR(HEX(uuid), 1, 8), '-',
           SUBSTR(HEX(uuid), 9, 4), '-',
           SUBSTR(HEX(uuid), 13, 4), '-',
           SUBSTR(HEX(uuid), 17, 4), '-',
           SUBSTR(HEX(uuid), 21)
           )),
          name,
          input,
          tries,
          next_run_at,
          max_tries,
          status,
          last_error,
          last_error_at
        FROM queue_jobs
        WHERE
          status = "pending"
          AND next_run_at <= NOW()
          AND tries < max_tries
        ORDER BY id DESC
        |sql}
  ;;

  let find_workable () =
    Sihl.Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.collect_list find_workable_request ()
        |> Lwt.map Sihl.Database.raise_error)
  ;;

  let query =
    Caqti_request.collect
      Caqti_type.unit
      job
      {sql|
        SELECT
          LOWER(CONCAT(
           SUBSTR(HEX(uuid), 1, 8), '-',
           SUBSTR(HEX(uuid), 9, 4), '-',
           SUBSTR(HEX(uuid), 13, 4), '-',
           SUBSTR(HEX(uuid), 17, 4), '-',
           SUBSTR(HEX(uuid), 21)
           )),
          name,
          input,
          tries,
          next_run_at,
          max_tries,
          status,
          last_error,
          last_error_at
        FROM queue_jobs
        ORDER BY next_run_at DESC
        LIMIT 100
        |sql}
  ;;

  let query () =
    Sihl.Database.query' (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.collect_list query ())
  ;;

  let find_request =
    Caqti_request.find_opt
      Caqti_type.string
      job
      {sql|
        SELECT
          LOWER(CONCAT(
           SUBSTR(HEX(uuid), 1, 8), '-',
           SUBSTR(HEX(uuid), 9, 4), '-',
           SUBSTR(HEX(uuid), 13, 4), '-',
           SUBSTR(HEX(uuid), 17, 4), '-',
           SUBSTR(HEX(uuid), 21)
           )),
          name,
          input,
          tries,
          next_run_at,
          max_tries,
          status,
          last_error,
          last_error_at
        FROM queue_jobs
        WHERE uuid = UNHEX(REPLACE(?, '-', ''))
        |sql}
  ;;

  let find id =
    Sihl.Database.query' (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.find_opt find_request id)
  ;;

  let delete_request =
    Caqti_request.exec
      Caqti_type.string
      {sql|
        DELETE FROM job_queues
        WHERE uuid = UNHEX(REPLACE(?, '-', ''))
        |sql}
  ;;

  let delete (job : Sihl.Contract.Queue.instance) =
    Sihl.Database.query' (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec delete_request job.id)
  ;;

  let clean_request =
    Caqti_request.exec Caqti_type.unit "TRUNCATE TABLE queue_jobs;"
  ;;

  let clean () =
    Sihl.Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec clean_request () |> Lwt.map Sihl.Database.raise_error)
  ;;

  module Migration = struct
    let fix_collation =
      Sihl.Database.Migration.create_step
        ~label:"fix collation"
        "SET collation_server = 'utf8mb4_unicode_ci';"
    ;;

    let create_jobs_table =
      Sihl.Database.Migration.create_step
        ~label:"create jobs table"
        {sql|
         CREATE TABLE IF NOT EXISTS queue_jobs (
           id BIGINT UNSIGNED AUTO_INCREMENT,
           uuid BINARY(16) NOT NULL,
           name VARCHAR(128) NOT NULL,
           input TEXT NULL,
           tries BIGINT UNSIGNED,
           next_run_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
           max_tries BIGINT UNSIGNED,
           status VARCHAR(128) NOT NULL,
           PRIMARY KEY (id),
           CONSTRAINT unique_uuid UNIQUE KEY (uuid)
         ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
         |sql}
    ;;

    let set_null_input_to_empty_string =
      Sihl.Database.Migration.create_step
        ~label:"set input to not null"
        {sql|
         UPDATE queue_jobs SET input = '' WHERE input IS NULL;
         |sql}
    ;;

    let set_input_not_null =
      Sihl.Database.Migration.create_step
        ~label:"set input to not null"
        {sql|
         ALTER TABLE queue_jobs MODIFY COLUMN input TEXT NOT NULL DEFAULT '';
         |sql}
    ;;

    let add_error_columns =
      Sihl.Database.Migration.create_step
        ~label:"add error columns"
        {sql|
         ALTER TABLE queue_jobs
           ADD COLUMN last_error TEXT,
           ADD COLUMN last_error_at TIMESTAMP;
         |sql}
    ;;

    let migration =
      Sihl.Database.Migration.(
        empty "queue"
        |> add_step fix_collation
        |> add_step create_jobs_table
        |> add_step set_null_input_to_empty_string
        |> add_step set_input_not_null
        |> add_step add_error_columns)
    ;;
  end

  let register_cleaner () = Sihl.Cleaner.register_cleaner clean

  let register_migration () =
    MigrationService.register_migration Migration.migration
  ;;
end

module MakePostgreSql (MigrationService : Sihl.Contract.Migration.Sig) = struct
  let lifecycles = [ Sihl.Database.lifecycle; MigrationService.lifecycle ]

  let enqueue_request =
    Caqti_request.exec
      job
      {sql|
        INSERT INTO queue_jobs (
          uuid,
          name,
          input,
          tries,
          next_run_at,
          max_tries,
          status,
          last_error,
          last_error_at
        ) VALUES (
          $1::uuid,
          $2,
          $3,
          $4,
          $5 AT TIME ZONE 'UTC',
          $6,
          $7,
          $8,
          $9 AT TIME ZONE 'UTC'
        )
        |sql}
  ;;

  let enqueue job_instance =
    Sihl.Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec enqueue_request job_instance
        |> Lwt.map Sihl.Database.raise_error)
  ;;

  let enqueue_all job_instances =
    Sihl.Database.transaction' (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.populate
          ~table:"queue_jobs"
          ~columns:
            [ "uuid"
            ; "name"
            ; "input"
            ; "tries"
            ; "next_run_at"
            ; "max_tries"
            ; "status"
            ; "last_error"
            ; "last_error_at"
            ]
          job
          (Caqti_lwt.Stream.of_list (List.rev job_instances))
        |> Lwt.map Caqti_error.uncongested)
  ;;

  let update_request =
    Caqti_request.exec
      job
      {sql|
        UPDATE queue_jobs
        SET
          name = $2,
          input = $3,
          tries = $4,
          next_run_at = $5 AT TIME ZONE 'UTC',
          max_tries = $6,
          status = $7,
          last_error = $8,
          last_error_at = $9 AT TIME ZONE 'UTC'
        WHERE
          queue_jobs.uuid = $1::uuid
        |sql}
  ;;

  let update job_instance =
    Sihl.Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec update_request job_instance
        |> Lwt.map Sihl.Database.raise_error)
  ;;

  let find_workable_request =
    Caqti_request.collect
      Caqti_type.unit
      job
      {sql|
        SELECT
          uuid,
          name,
          input,
          tries,
          next_run_at,
          max_tries,
          status,
          last_error,
          last_error_at
        FROM queue_jobs
        WHERE
          status = 'pending'
          AND next_run_at <= NOW()
          AND tries < max_tries
        ORDER BY id DESC
        |sql}
  ;;

  let find_workable () =
    Sihl.Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.collect_list find_workable_request ()
        |> Lwt.map Sihl.Database.raise_error)
  ;;

  let query =
    Caqti_request.collect
      Caqti_type.unit
      job
      {sql|
        SELECT
          uuid,
          name,
          input,
          tries,
          next_run_at,
          max_tries,
          status,
          last_error,
          last_error_at
        FROM queue_jobs
        ORDER BY next_run_at DESC
        |sql}
  ;;

  let query () =
    Sihl.Database.query' (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.collect_list query ())
  ;;

  let find_request =
    Caqti_request.find_opt
      Caqti_type.string
      job
      {sql|
        SELECT
          uuid,
          name,
          input,
          tries,
          next_run_at,
          max_tries,
          status,
          last_error,
          last_error_at
        FROM queue_jobs
        WHERE uuid = ?::uuid
        |sql}
  ;;

  let find id =
    Sihl.Database.query' (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.find_opt find_request id)
  ;;

  let delete_request =
    Caqti_request.exec
      Caqti_type.string
      {sql|
        DELETE FROM job_queues
        WHERE uuid = ?::uuid
        |sql}
  ;;

  let delete (job : Sihl.Contract.Queue.instance) =
    Sihl.Database.query' (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec delete_request job.id)
  ;;

  let clean_request =
    Caqti_request.exec Caqti_type.unit "TRUNCATE TABLE queue_jobs;"
  ;;

  let clean () =
    Sihl.Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec clean_request () |> Lwt.map Sihl.Database.raise_error)
  ;;

  module Migration = struct
    let create_jobs_table =
      Sihl.Database.Migration.create_step
        ~label:"create jobs table"
        {sql|
         CREATE TABLE IF NOT EXISTS queue_jobs (
           id serial,
           uuid uuid NOT NULL,
           name VARCHAR(128) NOT NULL,
           input TEXT NULL,
           tries BIGINT,
           next_run_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
           max_tries BIGINT,
           status VARCHAR(128) NOT NULL,
           PRIMARY KEY (id),
           UNIQUE (uuid)
         );
         |sql}
    ;;

    let set_null_input_to_empty_string =
      Sihl.Database.Migration.create_step
        ~label:"set input to not null"
        {sql|
         UPDATE queue_jobs SET input = '' WHERE input IS NULL;
         |sql}
    ;;

    let set_input_not_null =
      Sihl.Database.Migration.create_step
        ~label:"set input to not null"
        {sql|
         ALTER TABLE queue_jobs
           ALTER COLUMN input SET DEFAULT '',
           ALTER COLUMN input SET NOT NULL;
         |sql}
    ;;

    let add_error_columns =
      Sihl.Database.Migration.create_step
        ~label:"add error columns"
        {sql|
         ALTER TABLE queue_jobs
           ADD COLUMN last_error TEXT NULL,
           ADD COLUMN last_error_at TIMESTAMP WITH TIME ZONE;
         |sql}
    ;;

    let remove_timezone =
      Sihl.Database.Migration.create_step
        ~label:"remove timezone info from timestamps"
        {sql|
         ALTER TABLE queue_jobs
          ALTER COLUMN next_run_at TYPE TIMESTAMP,
          ALTER COLUMN last_error_at TYPE TIMESTAMP;
         |sql}
    ;;

    let migration =
      Sihl.Database.Migration.(
        empty "queue"
        |> add_step create_jobs_table
        |> add_step set_null_input_to_empty_string
        |> add_step set_input_not_null
        |> add_step add_error_columns
        |> add_step remove_timezone)
    ;;
  end

  let register_cleaner () = Sihl.Cleaner.register_cleaner clean

  let register_migration () =
    MigrationService.register_migration Migration.migration
  ;;
end
