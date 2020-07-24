open Base

let ( let* ) = Lwt.bind

module Job = Queue_core.Job
module JobInstance = Queue_core.JobInstance

let registered_jobs () : 'a Job.t list ref = ref []

module MakePolling
    (Log : Log_sig.SERVICE)
    (Db : Data_db_sig.SERVICE)
    (RepoService : Data.Repo.Sig.SERVICE)
    (MigrationService : Data.Migration.Sig.SERVICE)
    (ScheduleService : Schedule.Sig.SERVICE)
    (QueueRepo : Queue_sig.REPO) : Queue_sig.SERVICE = struct
  let on_init ctx =
    let ( let* ) = Lwt_result.bind in
    let* () = MigrationService.register ctx (QueueRepo.migrate ()) in
    RepoService.register_cleaner ctx QueueRepo.clean

  let on_stop _ = Lwt.return @@ Ok ()

  let register_jobs _ ~jobs =
    registered_jobs () := jobs;
    Lwt.return ()

  let dispatch ctx ~job ?delay input =
    let input = Job.input_to_string job input in
    let name = Job.name job in
    let now = Ptime_clock.now () in
    let start_at =
      delay
      |> Option.map ~f:Utils.Time.duration_to_span
      |> Option.bind ~f:(Ptime.add_span now)
      |> Option.value ~default:now
    in
    let job_instance = JobInstance.create ~input ~name ~start_at in
    QueueRepo.enqueue ~job_instance
    |> Db.query ctx
    |> Lwt_result.map_err (fun msg ->
           "QUEUE: Failure while enqueuing job instance: " ^ msg)
    |> Lwt.map Result.ok_or_failwith

  let run_job ctx input_string ~job ~job_instance =
    let job_instance_id = JobInstance.id job_instance in
    match Job.string_to_input job input_string with
    | Error msg ->
        Log.err (fun m ->
            m "QUEUE: Unexpected input %s found for job instance %a %s"
              (Option.value ~default:"-" input_string)
              JobInstance.pp job_instance msg);
        Lwt.return None
    | Ok input -> (
        let* result =
          Lwt.catch
            (fun () -> Job.handle job ctx ~input)
            (fun exn ->
              let exn_string = Exn.to_string exn in
              Lwt.return
              @@ Error
                   ( "Exception caught while running job, this is a bug in \
                      your job handler, make sure to not throw exceptions "
                   ^ exn_string ))
        in
        match result with
        | Error msg -> (
            Logs.err (fun m ->
                m "QUEUE: Failure while running job instance %a %s"
                  JobInstance.pp job_instance msg);
            let* result =
              Lwt.catch
                (fun () -> Job.failed job ctx)
                (fun exn ->
                  let exn_string = Exn.to_string exn in
                  Lwt.return
                  @@ Error
                       ( "Exception caught while cleaning up job, this is a \
                          bug in your job failure handler, make sure to not \
                          throw exceptions " ^ exn_string ))
            in
            match result with
            | Error msg ->
                Logs.err (fun m ->
                    m
                      "QUEUE: Failure while run failure handler for job \
                       instance %a %s"
                      JobInstance.pp job_instance msg);
                Lwt.return None
            | Ok () ->
                Logs.err (fun m ->
                    m "QUEUE: Failure while cleaning up job instance %a"
                      Uuidm.pp job_instance_id);
                Lwt.return None )
        | Ok () ->
            Logs.debug (fun m ->
                m "QUEUE: Successfully ran job instance %a" Uuidm.pp
                  job_instance_id);
            Lwt.return @@ Some () )

  let update ctx ~job_instance = QueueRepo.update ~job_instance |> Db.query ctx

  let work_job ctx ~job ~job_instance =
    let now = Ptime_clock.now () in
    if JobInstance.should_run ~job ~job_instance ~now then
      let input_string = JobInstance.input job_instance in
      let* job_run_status = run_job ctx input_string ~job ~job_instance in
      let job_instance =
        job_instance |> JobInstance.incr_tries
        |> JobInstance.set_last_ran_at now
      in
      let job_instance =
        match job_run_status with
        | None ->
            if JobInstance.tries job_instance >= Job.max_tries job then
              JobInstance.set_failed job_instance
            else job_instance
        | Some () -> JobInstance.set_succeeded job_instance
      in
      update ctx ~job_instance
      |> Lwt_result.map_err (fun msg ->
             "QUEUE: Failure while updating job instance: " ^ msg)
      |> Lwt.map Result.ok_or_failwith
    else (
      Log.debug (fun m ->
          m "QUEUE: Not going to run job instance %a" JobInstance.pp
            job_instance);
      Lwt.return () )

  let work_queue ctx ~jobs =
    let* pending_job_instances =
      QueueRepo.find_pending |> Db.query ctx
      |> Lwt_result.map_err (fun msg ->
             "QUEUE: Failure while finding pending job instances " ^ msg)
      |> Lwt.map Result.ok_or_failwith
    in
    Log.debug (fun m ->
        m "QUEUE: Start working queue of length %d"
          (List.length pending_job_instances));

    let rec loop job_instances jobs =
      match job_instances with
      | [] -> Lwt.return ()
      | job_instance :: job_instances -> (
          let job =
            List.find jobs ~f:(fun job ->
                job |> Job.name |> String.equal (JobInstance.name job_instance))
          in
          match job with
          | None -> loop job_instances jobs
          | Some job -> work_job ctx ~job ~job_instance )
    in
    loop pending_job_instances jobs

  let on_start ctx =
    let jobs = !(registered_jobs ()) in
    let schedule =
      Schedule.create Schedule.every_second ~f:(fun ctx -> work_queue ctx ~jobs)
    in
    ScheduleService.schedule ctx schedule;
    Lwt_result.return ()
end

module Repo = Queue_service_repo
