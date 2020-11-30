let should_run_job _ () =
  let now = Ptime_clock.now () in
  let job =
    Sihl_type.Queue_job.create
      ~name:"foo"
      ~input_to_string:(fun _ -> None)
      ~string_to_input:(fun _ -> Ok None)
      ~handle:(fun ~input:_ -> Lwt_result.return ())
      ~failed:(fun _ -> Lwt_result.return ())
      ()
    |> Sihl_type.Queue_job.set_max_tries 3
    |> Sihl_type.Queue_job.set_retry_delay Sihl_core.Time.OneMinute
  in
  let job_instance =
    Sihl_type.Queue_job_instance.create ~input:None ~delay:None ~now job
  in
  let actual = Sihl_type.Queue_job_instance.should_run ~job_instance ~now in
  Alcotest.(check bool) "pending job should run" true actual;
  let delay = Some Sihl_core.Time.OneDay in
  let job_instance = Sihl_type.Queue_job_instance.create ~input:None ~delay ~now job in
  let actual = Sihl_type.Queue_job_instance.should_run ~job_instance ~now in
  Alcotest.(check bool)
    "pending job with start_at in the future should not run"
    false
    actual;
  let job_instance =
    Sihl_type.Queue_job_instance.create ~input:None ~delay:None ~now job
    |> Sihl_type.Queue_job_instance.incr_tries
    |> Sihl_type.Queue_job_instance.incr_tries
  in
  let actual = Sihl_type.Queue_job_instance.should_run ~job_instance ~now in
  Alcotest.(check bool) "pending job with tries < max_tries should not run" true actual;
  let job_instance =
    Sihl_type.Queue_job_instance.create ~input:None ~delay:None ~now job
    |> Sihl_type.Queue_job_instance.incr_tries
    |> Sihl_type.Queue_job_instance.incr_tries
    |> Sihl_type.Queue_job_instance.incr_tries
  in
  let actual = Sihl_type.Queue_job_instance.should_run ~job_instance ~now in
  Alcotest.(check bool) "pending job with tries = max_tries should not run" false actual;
  let job_instance =
    Sihl_type.Queue_job_instance.create ~input:None ~delay:None ~now job
    |> Sihl_type.Queue_job_instance.set_failed
  in
  let actual = Sihl_type.Queue_job_instance.should_run ~job_instance ~now in
  Alcotest.(check bool) "failed job should not run" false actual;
  let job_instance =
    Sihl_type.Queue_job_instance.create ~input:None ~delay:None ~now job
    |> Sihl_type.Queue_job_instance.set_succeeded
  in
  let actual = Sihl_type.Queue_job_instance.should_run ~job_instance ~now in
  Alcotest.(check bool) "succeeded job should not run" false actual;
  let workable_job = job |> Sihl_type.Queue_workable_job.of_job in
  let job_instance =
    Sihl_type.Queue_job_instance.create ~input:None ~delay:None ~now job
    |> Sihl_type.Queue_job_instance.update_next_run_at workable_job
  in
  let actual = Sihl_type.Queue_job_instance.should_run ~job_instance ~now in
  Alcotest.(check bool) "job that hasn't cooled down should not run" false actual;
  Lwt.return ()
;;

let suite = Alcotest_lwt.[ "queue", [ test_case "should job run" `Quick should_run_job ] ]

let () =
  Unix.putenv "SIHL_ENV" "test";
  Lwt_main.run (Alcotest_lwt.run "queue" suite)
;;
