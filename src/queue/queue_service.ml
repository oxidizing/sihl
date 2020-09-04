open Base
open Lwt.Syntax
module Job = Queue_core.Job
module WorkableJob = Queue_core.WorkableJob
module JobInstance = Queue_core.JobInstance
module Sig = Queue_service_sig

let registered_jobs : WorkableJob.t list ref = ref []

let stop_schedule : (unit -> unit) option ref = ref None

module MakePolling
    (Log : Log.Service.Sig.SERVICE)
    (ScheduleService : Schedule.Service.Sig.SERVICE)
    (Repo : Sig.REPO) : Sig.SERVICE = struct
  let dispatch ctx ~job ?delay input =
    let name = Job.name job in
    Log.debug (fun m -> m "QUEUE: Dispatching job %s" name);
    let now = Ptime_clock.now () in
    let job_instance = JobInstance.create ~input ~delay ~now job in
    Repo.enqueue ctx ~job_instance

  let run_job ctx input ~job ~job_instance =
    let job_instance_id = JobInstance.id job_instance in
    let* result =
      Lwt.catch
        (fun () -> WorkableJob.work job ctx ~input)
        (fun exn ->
          let exn_string = Exn.to_string exn in
          Lwt.return
          @@ Error
               ( "Exception caught while running job, this is a bug in your \
                  job handler, make sure to not throw exceptions " ^ exn_string
               ))
    in
    match result with
    | Error msg -> (
        Log.err (fun m ->
            m "QUEUE: Failure while running job instance %a %s" JobInstance.pp
              job_instance msg);
        let* result =
          Lwt.catch
            (fun () -> WorkableJob.failed job ctx)
            (fun exn ->
              let exn_string = Exn.to_string exn in
              Lwt.return
              @@ Error
                   ( "Exception caught while cleaning up job, this is a bug in \
                      your job failure handler, make sure to not throw \
                      exceptions " ^ exn_string ))
        in
        match result with
        | Error msg ->
            Log.err (fun m ->
                m
                  "QUEUE: Failure while run failure handler for job instance \
                   %a %s"
                  JobInstance.pp job_instance msg);
            Lwt.return None
        | Ok () ->
            Log.err (fun m ->
                m "QUEUE: Clean up job %a" Uuidm.pp job_instance_id);
            Lwt.return None )
    | Ok () ->
        Log.debug (fun m ->
            m "QUEUE: Successfully ran job instance %a" Uuidm.pp job_instance_id);
        Lwt.return @@ Some ()

  let update ctx ~job_instance = Repo.update ctx ~job_instance

  let work_job ctx ~job ~job_instance =
    let now = Ptime_clock.now () in
    if JobInstance.should_run ~job_instance ~now then
      let input_string = JobInstance.input job_instance in
      let* job_run_status = run_job ctx input_string ~job ~job_instance in
      let job_instance =
        job_instance |> JobInstance.incr_tries
        |> JobInstance.update_next_run_at job
      in
      let job_instance =
        match job_run_status with
        | None ->
            if JobInstance.tries job_instance >= WorkableJob.max_tries job then
              JobInstance.set_failed job_instance
            else job_instance
        | Some () -> JobInstance.set_succeeded job_instance
      in
      update ctx ~job_instance
    else (
      Log.debug (fun m ->
          m "QUEUE: Not going to run job instance %a" JobInstance.pp
            job_instance);
      Lwt.return () )

  let work_queue ctx ~jobs =
    let* pending_job_instances = Repo.find_workable ctx in
    let n_job_instances = List.length pending_job_instances in
    if n_job_instances > 0 then (
      Log.debug (fun m ->
          m "QUEUE: Start working queue of length %d"
            (List.length pending_job_instances));

      let rec loop job_instances jobs =
        match job_instances with
        | [] -> Lwt.return ()
        | job_instance :: job_instances -> (
            let job =
              List.find jobs ~f:(fun job ->
                  job |> WorkableJob.name
                  |> String.equal (JobInstance.name job_instance))
            in
            match job with
            | None -> loop job_instances jobs
            | Some job -> work_job ctx ~job ~job_instance )
      in
      let* () = loop pending_job_instances jobs in
      Log.debug (fun m -> m "QUEUE: Finish working queue");
      Lwt.return () )
    else Lwt.return ()

  let register_jobs _ ~jobs =
    let jobs_to_register = jobs |> List.map ~f:WorkableJob.of_job in
    registered_jobs := List.concat [ !registered_jobs; jobs_to_register ];
    Lwt.return ()

  let start_queue ctx =
    Log.debug (fun m -> m "QUEUE: Start job queue");
    (* This function run every second, the request context gets created here with each tick *)
    let scheduled_function () =
      let jobs = !registered_jobs in
      if List.length jobs > 0 then (
        let job_strings =
          jobs |> List.map ~f:WorkableJob.name |> String.concat ~sep:", "
        in
        Logs.debug (fun m ->
            m "QUEUE: Run job queue with registered jobs: %s" job_strings);
        (* Combine all context middleware functions of registered jobs to get the context the jobs run with*)
        let combined_context_fn =
          jobs
          |> List.map ~f:WorkableJob.with_context
          |> List.fold ~init:Fn.id ~f:Fn.compose
        in
        let ctx = combined_context_fn Core.Ctx.empty in
        work_queue ctx ~jobs )
      else (
        Logs.debug (fun m ->
            m "QUEUE: No jobs found to run, trying again later");
        Lwt.return () )
    in

    let schedule =
      Schedule.create Schedule.every_second ~f:scheduled_function
        ~label:"job_queue"
    in
    stop_schedule := Some (ScheduleService.schedule ctx schedule);
    Lwt.return ()

  let lifecycle =
    Core.Container.Lifecycle.make "queue"
      ~dependencies:[ ScheduleService.lifecycle; Log.lifecycle ]
      (fun ctx ->
        Repo.register_migration ();
        Repo.register_cleaner ();
        start_queue ctx |> Lwt.map (fun () -> ctx))
      (fun _ ->
        registered_jobs := [];
        match !stop_schedule with
        | Some stop_schedule ->
            stop_schedule ();
            Lwt.return ()
        | None ->
            Log.warn (fun m -> m "QUEUE: Can not stop schedule");
            Lwt.return ())
end

module Repo = Queue_service_repo
