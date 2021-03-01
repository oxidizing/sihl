open Alcotest_lwt
open Lwt.Syntax

let should_run_job _ () =
  let now = Ptime_clock.now () in
  let job =
    Sihl_queue.create
      ~name:"foo"
      ~input_to_string:(fun _ -> None)
      ~string_to_input:(fun _ -> Ok None)
      ~handle:(fun _ -> Lwt_result.return ())
      ~failed:(fun _ -> Lwt_result.return ())
      ()
    |> Sihl_queue.set_max_tries 3
    |> Sihl_queue.set_retry_delay Sihl.Time.OneMinute
  in
  let job_instance =
    Sihl_queue.Job_instance.create ~input:None ~delay:None ~now job
  in
  let actual = Sihl_queue.Job_instance.should_run ~job_instance ~now in
  Alcotest.(check bool) "pending job should run" true actual;
  let delay = Some Sihl.Time.OneDay in
  let job_instance =
    Sihl_queue.Job_instance.create ~input:None ~delay ~now job
  in
  let actual = Sihl_queue.Job_instance.should_run ~job_instance ~now in
  Alcotest.(check bool)
    "pending job with start_at in the future should not run"
    false
    actual;
  let job_instance =
    Sihl_queue.Job_instance.create ~input:None ~delay:None ~now job
    |> Sihl_queue.Job_instance.incr_tries
    |> Sihl_queue.Job_instance.incr_tries
  in
  let actual = Sihl_queue.Job_instance.should_run ~job_instance ~now in
  Alcotest.(check bool)
    "pending job with tries < max_tries should not run"
    true
    actual;
  let job_instance =
    Sihl_queue.Job_instance.create ~input:None ~delay:None ~now job
    |> Sihl_queue.Job_instance.incr_tries
    |> Sihl_queue.Job_instance.incr_tries
    |> Sihl_queue.Job_instance.incr_tries
  in
  let actual = Sihl_queue.Job_instance.should_run ~job_instance ~now in
  Alcotest.(check bool)
    "pending job with tries = max_tries should not run"
    false
    actual;
  let job_instance =
    Sihl_queue.Job_instance.create ~input:None ~delay:None ~now job
    |> Sihl_queue.Job_instance.set_failed
  in
  let actual = Sihl_queue.Job_instance.should_run ~job_instance ~now in
  Alcotest.(check bool) "failed job should not run" false actual;
  let job_instance =
    Sihl_queue.Job_instance.create ~input:None ~delay:None ~now job
    |> Sihl_queue.Job_instance.set_succeeded
  in
  let actual = Sihl_queue.Job_instance.should_run ~job_instance ~now in
  Alcotest.(check bool) "succeeded job should not run" false actual;
  let workable_job = job |> Sihl_queue.Workable_job.of_job in
  let job_instance =
    Sihl_queue.Job_instance.create ~input:None ~delay:None ~now job
    |> Sihl_queue.Job_instance.update_next_run_at workable_job
  in
  let actual = Sihl_queue.Job_instance.should_run ~job_instance ~now in
  Alcotest.(check bool)
    "job that hasn't cooled down should not run"
    false
    actual;
  Lwt.return ()
;;

module Make (QueueService : Sihl.Contract.Queue.Sig) = struct
  let dispatched_job_gets_processed _ () =
    let has_ran_job = ref false in
    let* () = Sihl.Container.stop_services [ QueueService.register () ] in
    let* () = Sihl.Cleaner.clean_all () in
    let job =
      Sihl_queue.create
        ~name:"foo"
        ~input_to_string:(fun _ -> None)
        ~string_to_input:(fun _ -> Ok ())
        ~handle:(fun _ -> Lwt_result.return (has_ran_job := true))
        ~failed:(fun _ -> Lwt_result.return ())
        ()
      |> Sihl_queue.set_max_tries 3
      |> Sihl_queue.set_retry_delay Sihl.Time.OneMinute
    in
    let service = QueueService.register ~jobs:[ job ] () in
    let* _ = Sihl.Container.start_services [ service ] in
    let* () = QueueService.dispatch job () in
    let* () = Lwt_unix.sleep 2.0 in
    let* () = Sihl.Container.stop_services [ service ] in
    let () = Alcotest.(check bool "has processed job" true !has_ran_job) in
    Lwt.return ()
  ;;

  let two_dispatched_jobs_get_processed _ () =
    let has_ran_job1 = ref false in
    let has_ran_job2 = ref false in
    let* () = Sihl.Container.stop_services [ QueueService.register () ] in
    let* () = Sihl.Cleaner.clean_all () in
    let job1 =
      Sihl_queue.create
        ~name:"foo1"
        ~input_to_string:(fun _ -> None)
        ~string_to_input:(fun _ -> Ok ())
        ~handle:(fun _ -> Lwt_result.return (has_ran_job1 := true))
        ~failed:(fun _ -> Lwt_result.return ())
        ()
      |> Sihl_queue.set_max_tries 3
      |> Sihl_queue.set_retry_delay Sihl.Time.OneMinute
    in
    let job2 =
      Sihl_queue.create
        ~name:"foo2"
        ~input_to_string:(fun _ -> None)
        ~string_to_input:(fun _ -> Ok ())
        ~handle:(fun _ -> Lwt_result.return (has_ran_job2 := true))
        ~failed:(fun _ -> Lwt_result.return ())
        ()
      |> Sihl_queue.set_max_tries 3
      |> Sihl_queue.set_retry_delay Sihl.Time.OneMinute
    in
    let service = QueueService.register ~jobs:[ job1; job2 ] () in
    let* _ = Sihl.Container.start_services [ service ] in
    let* () = QueueService.dispatch job1 () in
    let* () = QueueService.dispatch job2 () in
    let* () = Lwt_unix.sleep 4.0 in
    let* () = Sihl.Container.stop_services [ service ] in
    let () = Alcotest.(check bool "has processed job1" true !has_ran_job1) in
    let () = Alcotest.(check bool "has processed job2" true !has_ran_job1) in
    Lwt.return ()
  ;;

  let cleans_up_job_after_error _ () =
    let has_cleaned_up_job = ref false in
    let* () = Sihl.Container.stop_services [ QueueService.register () ] in
    let* () = Sihl.Cleaner.clean_all () in
    let job =
      Sihl_queue.create
        ~name:"foo"
        ~input_to_string:(fun _ -> None)
        ~string_to_input:(fun _ -> Ok ())
        ~handle:(fun _ -> Lwt_result.fail "didn't work")
        ~failed:(fun _ -> Lwt_result.return (has_cleaned_up_job := true))
        ()
      |> Sihl_queue.set_max_tries 3
      |> Sihl_queue.set_retry_delay Sihl.Time.OneMinute
    in
    let service = QueueService.register ~jobs:[ job ] () in
    let* _ = Sihl.Container.start_services [ service ] in
    let* () = QueueService.dispatch job () in
    let* () = Lwt_unix.sleep 2.0 in
    let* () = Sihl.Container.stop_services [ service ] in
    let () =
      Alcotest.(check bool "has cleaned up job" true !has_cleaned_up_job)
    in
    Lwt.return ()
  ;;

  let cleans_up_job_after_exception _ () =
    let has_cleaned_up_job = ref false in
    let* () = Sihl.Container.stop_services [ QueueService.register () ] in
    let* () = Sihl.Cleaner.clean_all () in
    let job =
      Sihl_queue.create
        ~name:"foo"
        ~input_to_string:(fun _ -> None)
        ~string_to_input:(fun _ -> Ok ())
        ~handle:(fun _ -> failwith "didn't work")
        ~failed:(fun _ -> Lwt_result.return (has_cleaned_up_job := true))
        ()
      |> Sihl_queue.set_max_tries 3
      |> Sihl_queue.set_retry_delay Sihl.Time.OneMinute
    in
    let service = QueueService.register ~jobs:[ job ] () in
    let* _ = Sihl.Container.start_services [ service ] in
    let* () = QueueService.dispatch job () in
    let* () = Lwt_unix.sleep 2.0 in
    let* () = Sihl.Container.stop_services [ service ] in
    let () =
      Alcotest.(check bool "has cleaned up job" true !has_cleaned_up_job)
    in
    Lwt.return ()
  ;;

  let suite =
    [ ( "queue"
      , [ test_case "should job run" `Quick should_run_job
        ; test_case
            "dispatched job gets processed"
            `Quick
            dispatched_job_gets_processed
        ; test_case
            "two dispatched jobs get processed"
            `Quick
            two_dispatched_jobs_get_processed
        ; test_case "cleans up job after error" `Quick cleans_up_job_after_error
        ; test_case
            "cleans up job after exception"
            `Quick
            cleans_up_job_after_exception
        ] )
    ]
  ;;
end
