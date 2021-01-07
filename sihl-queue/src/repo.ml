module Map = Map.Make (String)

module type Sig = sig
  val lifecycles : Sihl_core.Container.Lifecycle.t list
  val register_migration : unit -> unit
  val register_cleaner : unit -> unit
  val enqueue : job_instance:Job_instance.t -> unit Lwt.t
  val find_workable : unit -> Job_instance.t list Lwt.t
  val update : job_instance:Job_instance.t -> unit Lwt.t
end

module InMemory : Sig = struct
  let lifecycles = [ Sihl_core.Cleaner.lifecycle ]
  let state = ref Map.empty
  let ordered_ids = ref []

  let register_cleaner () =
    let cleaner _ =
      state := Map.empty;
      ordered_ids := [];
      Lwt.return ()
    in
    Sihl_core.Cleaner.register_cleaner cleaner
  ;;

  let register_migration () = ()

  let enqueue ~job_instance =
    let open Job_instance in
    let id = job_instance.id in
    ordered_ids := List.cons id !ordered_ids;
    state := Map.add id job_instance !state;
    Lwt.return ()
  ;;

  let update ~job_instance =
    let open Job_instance in
    let id = job_instance.id in
    state := Map.add id job_instance !state;
    Lwt.return ()
  ;;

  let find_workable () =
    let all_job_instances =
      List.map (fun id -> Map.find_opt id !state) !ordered_ids
    in
    let now = Ptime_clock.now () in
    let rec filter_pending all_job_instances result =
      match all_job_instances with
      | Some job_instance :: job_instances ->
        if Job_instance.should_run ~job_instance ~now
        then filter_pending job_instances (List.cons job_instance result)
        else filter_pending job_instances result
      | None :: job_instances -> filter_pending job_instances result
      | [] -> result
    in
    Lwt.return @@ filter_pending all_job_instances []
  ;;
end

let status =
  let open Job_instance in
  let encode m = Ok (Status.to_string m) in
  let decode = Status.of_string in
  Caqti_type.(custom ~encode ~decode string)
;;

let job =
  let open Job_instance in
  let encode m =
    Ok
      ( m.id
      , (m.name, (m.input, (m.tries, (m.next_run_at, (m.max_tries, m.status)))))
      )
  in
  let decode (id, (name, (input, (tries, (next_run_at, (max_tries, status)))))) =
    Ok { id; name; input; tries; next_run_at; max_tries; status }
  in
  Caqti_type.(
    custom
      ~encode
      ~decode
      (tup2
         string
         (tup2
            string
            (tup2 (option string) (tup2 int (tup2 ptime (tup2 int status)))))))
;;

module MakeMariaDb (MigrationService : Sihl_contract.Migration.Sig) : Sig =
struct
  let lifecycles =
    [ Sihl_persistence.Database.lifecycle
    ; Sihl_core.Cleaner.lifecycle
    ; MigrationService.lifecycle
    ]
  ;;

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
          status
        ) VALUES (
          UNHEX(REPLACE(?, '-', '')),
          ?,
          ?,
          ?,
          ?,
          ?,
          ?
        )
        |sql}
  ;;

  let enqueue ~job_instance =
    Sihl_persistence.Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec enqueue_request job_instance
        |> Lwt.map Sihl_persistence.Database.raise_error)
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
          status = $7
        WHERE
          queue_jobs.uuid = UNHEX(REPLACE($1, '-', ''))
        |sql}
  ;;

  let update ~job_instance =
    Sihl_persistence.Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec update_request job_instance
        |> Lwt.map Sihl_persistence.Database.raise_error)
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
          status
        FROM queue_jobs
        WHERE
          status = "pending"
          AND next_run_at <= NOW()
          AND tries < max_tries
        ORDER BY id DESC
        |sql}
  ;;

  let find_workable () =
    Sihl_persistence.Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.collect_list find_workable_request ()
        |> Lwt.map Sihl_persistence.Database.raise_error)
  ;;

  let clean_request =
    Caqti_request.exec Caqti_type.unit "TRUNCATE TABLE queue_jobs;"
  ;;

  let clean () =
    Sihl_persistence.Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec clean_request ()
        |> Lwt.map Sihl_persistence.Database.raise_error)
  ;;

  module Migration = struct
    let fix_collation =
      Sihl_facade.Migration.create_step
        ~label:"fix collation"
        "SET collation_server = 'utf8mb4_unicode_ci';"
    ;;

    let create_jobs_table =
      Sihl_facade.Migration.create_step
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

    let migration =
      Sihl_facade.Migration.(
        empty "queue" |> add_step fix_collation |> add_step create_jobs_table)
    ;;
  end

  let register_cleaner () = Sihl_core.Cleaner.register_cleaner clean

  let register_migration () =
    MigrationService.register_migration Migration.migration
  ;;
end

module MakePostgreSql (MigrationService : Sihl_contract.Migration.Sig) : Sig =
struct
  let lifecycles =
    [ Sihl_persistence.Database.lifecycle
    ; Sihl_core.Cleaner.lifecycle
    ; MigrationService.lifecycle
    ]
  ;;

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
          status
        ) VALUES (
          ?,
          ?,
          ?,
          ?,
          ?,
          ?,
          ?
        )
        |sql}
  ;;

  let enqueue ~job_instance =
    Sihl_persistence.Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec enqueue_request job_instance
        |> Lwt.map Sihl_persistence.Database.raise_error)
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
          status = $7
        WHERE
          queue_jobs.uuid = $1::uuid
        |sql}
  ;;

  let update ~job_instance =
    Sihl_persistence.Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec update_request job_instance
        |> Lwt.map Sihl_persistence.Database.raise_error)
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
          status
        FROM queue_jobs
        WHERE
          status = 'pending'
          AND next_run_at <= NOW()
          AND tries < max_tries
        ORDER BY id DESC
        |sql}
  ;;

  let find_workable () =
    Sihl_persistence.Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.collect_list find_workable_request ()
        |> Lwt.map Sihl_persistence.Database.raise_error)
  ;;

  let clean_request =
    Caqti_request.exec Caqti_type.unit "TRUNCATE TABLE queue_jobs;"
  ;;

  let clean () =
    Sihl_persistence.Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec clean_request ()
        |> Lwt.map Sihl_persistence.Database.raise_error)
  ;;

  module Migration = struct
    let create_jobs_table =
      Sihl_facade.Migration.create_step
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

    let migration =
      Sihl_facade.Migration.(empty "queue" |> add_step create_jobs_table)
    ;;
  end

  let register_cleaner () = Sihl_core.Cleaner.register_cleaner clean

  let register_migration () =
    MigrationService.register_migration Migration.migration
  ;;
end
