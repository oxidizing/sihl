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

type ctx = (string * string) list [@@deriving yojson]

let ctx =
  let to_string m = m |> ctx_to_yojson |> Yojson.Safe.to_string in
  let of_string m =
    try Yojson.Safe.from_string m |> ctx_of_yojson with
    | _ -> Error (Format.sprintf "failed to decode ctx %s" m)
  in
  let encode m = Ok (to_string m) in
  let decode = of_string in
  Caqti_type.(custom ~encode ~decode Caqti_type.string)
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
              , ( m.max_tries
                , ( m.status
                  , (m.last_error, (m.last_error_at, (m.tag, Some m.ctx))) ) )
              ) ) ) ) )
  in
  let decode
        ( id
        , ( name
          , ( input
            , ( tries
              , ( next_run_at
                , ( max_tries
                  , (status, (last_error, (last_error_at, (tag, ctx)))) ) ) ) )
          ) )
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
      ; tag
      ; ctx = Option.value ~default:[] ctx
      }
  in
  Caqti_type.(
    custom
      ~encode
      ~decode
      (t2
         string
         (t2
            string
            (t2
               string
               (t2
                  int
                  (t2
                     ptime
                     (t2
                        int
                        (t2
                           status
                           (t2
                              (option string)
                              (t2
                                 (option ptime)
                                 (t2 (option string) (option ctx))))))))))))
;;

module MakeMariaDb (MigrationService : Sihl.Contract.Migration.Sig) = struct
  let lifecycles = [ Sihl.Database.lifecycle; MigrationService.lifecycle ]

  let enqueue_request =
    let open Caqti_request.Infix in
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
        last_error_at,
        tag,
        ctx
      ) VALUES (
        UNHEX(REPLACE($1, '-', '')),
        $2,
        $3,
        $4,
        $5,
        $6,
        $7,
        $8,
        $9,
        $10,
        $11
      )
    |sql}
    |> job ->. Caqti_type.unit
  ;;

  let enqueue ?ctx job_instance =
    Sihl.Database.exec ?ctx enqueue_request job_instance
  ;;

  (* MariaDB expects uuid to be bytes, since we can't unhex when using caqti's
     populate, we have to do that manually. *)
  let populatable job_instances =
    job_instances
    |> List.map (fun j ->
      Sihl.Contract.Queue.
        { j with
          id =
            (match j.id |> Sihl.Random.Uuid.of_string with
             | Some uuid -> Sihl.Random.Uuid.to_binary_string uuid
             | None -> failwith "Invalid uuid provided")
        })
  ;;

  let enqueue_all ?ctx job_instances =
    Sihl.Database.transaction' ?ctx (fun connection ->
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
          ; "tag"
          ; "ctx"
          ]
        job
        (job_instances |> populatable |> List.rev |> Caqti_lwt.Stream.of_list)
      |> Lwt.map Caqti_error.uncongested)
  ;;

  let update_request =
    let open Caqti_request.Infix in
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
        last_error_at = $9,
        tag = $10,
        ctx = $11
      WHERE
        queue_jobs.uuid = UNHEX(REPLACE($1, '-', ''))
    |sql}
    |> job ->. Caqti_type.unit
  ;;

  let update ?ctx job_instance =
    Sihl.Database.exec ?ctx update_request job_instance
  ;;

  let find_workable_request =
    let open Caqti_request.Infix in
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
        last_error_at,
        tag,
        ctx
      FROM queue_jobs
      WHERE
        status = "pending"
        AND next_run_at <= NOW()
        AND tries < max_tries
      ORDER BY id DESC
    |sql}
    |> Caqti_type.unit ->* job
  ;;

  let find_workable ?ctx () =
    Sihl.Database.collect ?ctx find_workable_request ()
  ;;

  let query =
    let open Caqti_request.Infix in
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
        last_error_at,
        tag,
        ctx
      FROM queue_jobs
      ORDER BY next_run_at DESC
      LIMIT 100
    |sql}
    |> Caqti_type.unit ->* job
  ;;

  let query ?ctx () = Sihl.Database.collect ?ctx query ()

  let find_request =
    let open Caqti_request.Infix in
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
        last_error_at,
        tag,
        ctx
      FROM queue_jobs
      WHERE uuid = UNHEX(REPLACE(?, '-', ''))
    |sql}
    |> Caqti_type.string ->? job
  ;;

  let find ?ctx id = Sihl.Database.find_opt ?ctx find_request id

  let delete_request =
    let open Caqti_request.Infix in
    {sql|
      DELETE FROM job_queues
      WHERE uuid = UNHEX(REPLACE(?, '-', ''))
    |sql}
    |> Caqti_type.(string ->. unit)
  ;;

  let delete ?ctx (job : Sihl.Contract.Queue.instance) =
    Sihl.Database.exec ?ctx delete_request job.id
  ;;

  let clean_request =
    let open Caqti_request.Infix in
    "TRUNCATE TABLE queue_jobs" |> Caqti_type.(unit ->. unit)
  ;;

  let clean ?ctx () = Sihl.Database.exec ?ctx clean_request ()

  let filter_fragment =
    {sql|
      WHERE queue_jobs.tag LIKE $1
    |sql}
  ;;

  let search_query =
    {sql|
      SELECT
        COUNT(*) OVER() as total,
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
        last_error_at,
        tag,
        ctx
      FROM queue_jobs
    |sql}
  ;;

  let request =
    Sihl.Database.prepare_search_request
      ~search_query
      ~filter_fragment
      ~sort_by_field:"id"
      job
  ;;

  let search ?ctx sort filter ~limit ~offset =
    Sihl.Database.run_search_request ?ctx request sort filter ~limit ~offset
  ;;

  module Migration = struct
    let fix_collation =
      Sihl.Database.Migration.create_step
        ~label:"fix collation"
        {sql|
          SET collation_server = 'utf8mb4_unicode_ci'
        |sql}
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
          ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        |sql}
    ;;

    let set_null_input_to_empty_string =
      Sihl.Database.Migration.create_step
        ~label:"set input to not null"
        {sql|
          UPDATE queue_jobs SET input = '' WHERE input IS NULL
        |sql}
    ;;

    let set_input_not_null =
      Sihl.Database.Migration.create_step
        ~label:"set input to not null"
        {sql|
          ALTER TABLE queue_jobs MODIFY COLUMN input TEXT NOT NULL DEFAULT ''
        |sql}
    ;;

    let add_error_columns =
      Sihl.Database.Migration.create_step
        ~label:"add error columns"
        {sql|
          ALTER TABLE queue_jobs
            ADD COLUMN last_error TEXT,
            ADD COLUMN last_error_at TIMESTAMP
        |sql}
    ;;

    let add_tag_column =
      Sihl.Database.Migration.create_step
        ~label:"add tag column"
        {sql|
          ALTER TABLE queue_jobs
            ADD COLUMN tag TEXT NULL
        |sql}
    ;;

    let add_ctx_column =
      Sihl.Database.Migration.create_step
        ~label:"add ctx column"
        {sql|
      ALTER TABLE queue_jobs
       ADD COLUMN ctx TEXT NULL
      |sql}
    ;;

    let migration =
      Sihl.Database.Migration.(
        empty "queue"
        |> add_step fix_collation
        |> add_step create_jobs_table
        |> add_step set_null_input_to_empty_string
        |> add_step set_input_not_null
        |> add_step add_error_columns
        |> add_step add_tag_column
        |> add_step add_ctx_column)
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
    let open Caqti_request.Infix in
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
        last_error_at,
        tag,
        ctx
      ) VALUES (
        $1::uuid,
        $2,
        $3,
        $4,
        $5 AT TIME ZONE 'UTC',
        $6,
        $7,
        $8,
        $9 AT TIME ZONE 'UTC',
        $10,
        $11
      )
    |sql}
    |> job ->. Caqti_type.unit
  ;;

  let enqueue ?ctx job_instance =
    Sihl.Database.exec ?ctx enqueue_request job_instance
  ;;

  let enqueue_all ?ctx job_instances =
    Sihl.Database.transaction' ?ctx (fun connection ->
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
          ; "tag"
          ; "ctx"
          ]
        job
        (Caqti_lwt.Stream.of_list (List.rev job_instances))
      |> Lwt.map Caqti_error.uncongested)
  ;;

  let update_request =
    let open Caqti_request.Infix in
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
        last_error_at = $9 AT TIME ZONE 'UTC',
        tag = $10,
        ctx = $11
      WHERE
        queue_jobs.uuid = $1::uuid
    |sql}
    |> job ->. Caqti_type.unit
  ;;

  let update ?ctx job_instance =
    Sihl.Database.exec ?ctx update_request job_instance
  ;;

  let find_workable_request =
    let open Caqti_request.Infix in
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
        last_error_at,
        tag,
        ctx
      FROM queue_jobs
      WHERE
        status = 'pending'
        AND next_run_at <= NOW()
        AND tries < max_tries
      ORDER BY id DESC
    |sql}
    |> Caqti_type.unit ->* job
  ;;

  let find_workable ?ctx () =
    Sihl.Database.collect ?ctx find_workable_request ()
  ;;

  let query =
    let open Caqti_request.Infix in
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
        last_error_at,
        tag,
        ctx
      FROM queue_jobs
      ORDER BY next_run_at DESC
    |sql}
    |> Caqti_type.unit ->* job
  ;;

  let query ?ctx () = Sihl.Database.collect ?ctx query ()

  let find_request =
    let open Caqti_request.Infix in
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
        last_error_at,
        tag,
        ctx
      FROM queue_jobs
      WHERE uuid = $1::uuid
    |sql}
    |> Caqti_type.string ->? job
  ;;

  let find ?ctx id = Sihl.Database.find_opt ?ctx find_request id

  let delete_request =
    let open Caqti_request.Infix in
    {sql|
      DELETE FROM job_queues
      WHERE uuid = $1::uuid
    |sql}
    |> Caqti_type.(string ->. unit)
  ;;

  let delete ?ctx (job : Sihl.Contract.Queue.instance) =
    Sihl.Database.exec ?ctx delete_request job.id
  ;;

  let clean_request =
    let open Caqti_request.Infix in
    "TRUNCATE TABLE queue_jobs" |> Caqti_type.(unit ->. unit)
  ;;

  let clean ?ctx () = Sihl.Database.exec ?ctx clean_request ()

  let filter_fragment =
    {sql|
      WHERE queue_jobs.tag LIKE $1
    |sql}
  ;;

  let search_query =
    {sql|
      SELECT
        COUNT(*) OVER() as total,
        uuid,
        name,
        input,
        tries,
        next_run_at,
        max_tries,
        status,
        last_error,
        last_error_at,
        tag,
        ctx
      FROM queue_jobs
    |sql}
  ;;

  let request =
    Sihl.Database.prepare_search_request
      ~search_query
      ~filter_fragment
      ~sort_by_field:"id"
      job
  ;;

  let search ?ctx sort filter ~limit ~offset =
    Sihl.Database.run_search_request ?ctx request sort filter ~limit ~offset
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
          )
        |sql}
    ;;

    let set_null_input_to_empty_string =
      Sihl.Database.Migration.create_step
        ~label:"set input to not null"
        {sql|
          UPDATE queue_jobs SET input = '' WHERE input IS NULL
        |sql}
    ;;

    let set_input_not_null =
      Sihl.Database.Migration.create_step
        ~label:"set input to not null"
        {sql|
          ALTER TABLE queue_jobs
            ALTER COLUMN input SET DEFAULT '',
            ALTER COLUMN input SET NOT NULL
        |sql}
    ;;

    let add_error_columns =
      Sihl.Database.Migration.create_step
        ~label:"add error columns"
        {sql|
          ALTER TABLE queue_jobs
            ADD COLUMN last_error TEXT NULL,
            ADD COLUMN last_error_at TIMESTAMP WITH TIME ZONE
        |sql}
    ;;

    let remove_timezone =
      Sihl.Database.Migration.create_step
        ~label:"remove timezone info from timestamps"
        {sql|
          ALTER TABLE queue_jobs
            ALTER COLUMN next_run_at TYPE TIMESTAMP,
            ALTER COLUMN last_error_at TYPE TIMESTAMP
        |sql}
    ;;

    let add_tag_column =
      Sihl.Database.Migration.create_step
        ~label:"add tag column"
        {sql|
          ALTER TABLE queue_jobs
            ADD COLUMN tag TEXT NULL
        |sql}
    ;;

    let add_ctx_column =
      Sihl.Database.Migration.create_step
        ~label:"add ctx column"
        {sql|
      ALTER TABLE queue_jobs
       ADD COLUMN ctx TEXT NULL
      |sql}
    ;;

    let migration =
      Sihl.Database.Migration.(
        empty "queue"
        |> add_step create_jobs_table
        |> add_step set_null_input_to_empty_string
        |> add_step set_input_not_null
        |> add_step add_error_columns
        |> add_step remove_timezone
        |> add_step add_tag_column
        |> add_step add_ctx_column)
    ;;
  end

  let register_cleaner () = Sihl.Cleaner.register_cleaner clean

  let register_migration () =
    MigrationService.register_migration Migration.migration
  ;;
end
