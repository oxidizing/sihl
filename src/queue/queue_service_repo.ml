open Base
module Job = Queue_core.Job
module JobInstance = Queue_core.JobInstance

module MakeMemory (RepoService : Data.Repo.Service.Sig.SERVICE) :
  Queue_service_sig.REPO = struct
  let state = ref (Map.empty (module String))

  let ordered_ids = ref []

  let register_cleaner _ =
    let cleaner _ =
      state := Map.empty (module String);
      ordered_ids := [];
      Lwt.return ()
    in
    RepoService.register_cleaner cleaner

  let register_migration () = ()

  let enqueue _ ~job_instance =
    let id = JobInstance.id job_instance |> Data.Id.to_string in
    ordered_ids := List.cons id !ordered_ids;
    state := Map.add_exn !state ~key:id ~data:job_instance;
    Lwt.return ()

  let update _ ~job_instance =
    let id = JobInstance.id job_instance |> Data.Id.to_string in
    state := Map.set !state ~key:id ~data:job_instance;
    Lwt.return ()

  let find_workable _ =
    let all_job_instances =
      List.map !ordered_ids ~f:(fun id -> Map.find !state id)
    in
    let now = Ptime_clock.now () in
    let rec filter_pending all_job_instances result =
      match all_job_instances with
      | Some job_instance :: job_instances ->
          if JobInstance.should_run ~job_instance ~now then
            filter_pending job_instances (List.cons job_instance result)
          else filter_pending job_instances result
      | None :: job_instances -> filter_pending job_instances result
      | [] -> result
    in
    Lwt.return @@ filter_pending all_job_instances []
end

module Model = struct
  open Queue_core.JobInstance

  let status =
    let encode m = Ok (Status.to_string m) in
    let decode = Status.of_string in
    Caqti_type.(custom ~encode ~decode string)

  let t =
    let encode m =
      Ok
        ( m.id,
          ( m.name,
            (m.input, (m.tries, (m.next_run_at, (m.max_tries, m.status)))) ) )
    in
    let decode (id, (name, (input, (tries, (next_run_at, (max_tries, status))))))
        =
      Ok { id; name; input; tries; next_run_at; max_tries; status }
    in
    Caqti_type.(
      custom ~encode ~decode
        (tup2 Data.Id.t
           (tup2 string
              (tup2 (option string) (tup2 int (tup2 ptime (tup2 int status)))))))
end

module MakeMariaDb
    (DbService : Data.Db.Service.Sig.SERVICE)
    (RepoService : Data.Repo.Service.Sig.SERVICE)
    (MigrationService : Data.Migration.Service.Sig.SERVICE) :
  Queue_service_sig.REPO = struct
  let enqueue_request =
    Caqti_request.exec Model.t
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

  let enqueue ctx ~job_instance =
    DbService.query ctx (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec enqueue_request job_instance)

  let update_request =
    Caqti_request.exec Model.t
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
          queue_jobs.uuid = $1
        |sql}

  let update ctx ~job_instance =
    DbService.query ctx (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec update_request job_instance)

  let find_workable_request =
    Caqti_request.collect Caqti_type.unit Model.t
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
          status = "pending"
          AND next_run_at <= NOW()
          AND tries < max_tries
        ORDER BY id DESC
        |sql}

  let find_workable ctx =
    DbService.query ctx (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.collect_list find_workable_request ())

  let clean_request =
    Caqti_request.exec Caqti_type.unit
      {sql|
        TRUNCATE TABLE email_templates;
         |sql}

  let clean ctx =
    DbService.query ctx (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec clean_request ())

  module Migration = struct
    let fix_collation =
      Data.Migration.create_step ~label:"fix collation"
        "SET collation_server = 'utf8mb4_unicode_ci';"

    let create_jobs_table =
      Data.Migration.create_step ~label:"create jobs table"
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

    let migration =
      Data.Migration.(
        empty "queue" |> add_step fix_collation |> add_step create_jobs_table)
  end

  let register_cleaner () = RepoService.register_cleaner clean

  let register_migration () = MigrationService.register Migration.migration
end
