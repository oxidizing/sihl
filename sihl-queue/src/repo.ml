module Job = Sihl_type.Queue_job
module JobInstance = Sihl_type.Queue_job_instance
module Map = Map.Make (String)

module type Sig = sig
  val register_migration : unit -> unit
  val register_cleaner : unit -> unit
  val enqueue : job_instance:JobInstance.t -> unit Lwt.t
  val find_workable : unit -> JobInstance.t list Lwt.t
  val update : job_instance:JobInstance.t -> unit Lwt.t
end

module Memory : Sig = struct
  let state = ref Map.empty
  let ordered_ids = ref []

  let register_cleaner () =
    let cleaner _ =
      state := Map.empty;
      ordered_ids := [];
      Lwt.return ()
    in
    Sihl_persistence.Repository.register_cleaner cleaner
  ;;

  let register_migration () = ()

  let enqueue ~job_instance =
    let id = JobInstance.id job_instance |> Sihl_type.Database.Id.to_string in
    ordered_ids := List.cons id !ordered_ids;
    state := Map.add id job_instance !state;
    Lwt.return ()
  ;;

  let update ~job_instance =
    let id = JobInstance.id job_instance |> Sihl_type.Database.Id.to_string in
    state := Map.add id job_instance !state;
    Lwt.return ()
  ;;

  let find_workable () =
    let all_job_instances = List.map (fun id -> Map.find_opt id !state) !ordered_ids in
    let now = Ptime_clock.now () in
    let rec filter_pending all_job_instances result =
      match all_job_instances with
      | Some job_instance :: job_instances ->
        if JobInstance.should_run ~job_instance ~now
        then filter_pending job_instances (List.cons job_instance result)
        else filter_pending job_instances result
      | None :: job_instances -> filter_pending job_instances result
      | [] -> result
    in
    Lwt.return @@ filter_pending all_job_instances []
  ;;
end

module Model = struct
  open JobInstance

  let status =
    let encode m = Ok (Status.to_string m) in
    let decode = Status.of_string in
    Caqti_type.(custom ~encode ~decode string)
  ;;

  let t =
    let encode m =
      Ok (m.id, (m.name, (m.input, (m.tries, (m.next_run_at, (m.max_tries, m.status))))))
    in
    let decode (id, (name, (input, (tries, (next_run_at, (max_tries, status)))))) =
      Ok { id; name; input; tries; next_run_at; max_tries; status }
    in
    Caqti_type.(
      custom
        ~encode
        ~decode
        (tup2
           Sihl_type.Database.Id.t
           (tup2 string (tup2 (option string) (tup2 int (tup2 ptime (tup2 int status)))))))
  ;;
end

module MakeMariaDb (MigrationService : Sihl_contract.Migration.Sig) : Sig = struct
  let enqueue_request =
    Caqti_request.exec
      Model.t
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
      Model.t
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
      Model.t
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
  ;;

  let find_workable () =
    Sihl_persistence.Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.collect_list find_workable_request ()
        |> Lwt.map Sihl_persistence.Database.raise_error)
  ;;

  let clean_request =
    Caqti_request.exec
      Caqti_type.unit
      {sql|
        TRUNCATE TABLE email_templates;
         |sql}
  ;;

  let clean () =
    Sihl_persistence.Database.query (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.exec clean_request () |> Lwt.map Sihl_persistence.Database.raise_error)
  ;;

  module Migration = struct
    let fix_collation =
      Sihl_type.Migration.create_step
        ~label:"fix collation"
        "SET collation_server = 'utf8mb4_unicode_ci';"
    ;;

    let create_jobs_table =
      Sihl_type.Migration.create_step
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
      Sihl_type.Migration.(
        empty "queue" |> add_step fix_collation |> add_step create_jobs_table)
    ;;
  end

  let register_cleaner () = Sihl_persistence.Repository.register_cleaner clean
  let register_migration () = MigrationService.register_migration Migration.migration
end
