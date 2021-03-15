open Alcotest_lwt
open Lwt.Syntax

let create_instance input delay now (job : 'a Sihl_queue.job) =
  let open Sihl_queue in
  let input = job.encode input in
  let name = job.name in
  let next_run_at =
    match delay with
    | Some delay -> Option.value (Ptime.add_span now delay) ~default:now
    | None -> now
  in
  let max_tries = job.max_tries in
  { id = Uuidm.v `V4 |> Uuidm.to_string
  ; name
  ; input
  ; tries = 0
  ; next_run_at
  ; max_tries
  ; status = Pending
  ; last_error = None
  ; last_error_at = None
  }
;;

let update_next_run_at
    (retry_delay : Ptime.Span.t)
    (job_instance : Sihl_queue.instance)
  =
  let open Sihl_queue in
  let next_run_at =
    match Ptime.add_span job_instance.next_run_at retry_delay with
    | Some date -> date
    | None -> failwith "Can not determine next run date of job"
  in
  { job_instance with next_run_at }
;;

let incr_tries job_instance =
  let open Sihl_queue in
  { job_instance with tries = job_instance.tries + 1 }
;;

let should_run_job _ () =
  let now = Ptime_clock.now () in
  let job =
    Sihl_queue.create_job
      (fun _ -> Lwt_result.return ())
      ~max_tries:3
      ~retry_delay:(Sihl.Time.Span.minutes 1)
      (fun () -> "")
      (fun _ -> Ok ())
      "foo"
  in
  let job_instance = create_instance () None now job in
  let actual = Sihl_queue.should_run job_instance now in
  Alcotest.(check bool) "pending job should run" true actual;
  let delay = Some (Sihl.Time.Span.days 1) in
  let job_instance = create_instance () delay now job in
  let actual = Sihl_queue.should_run job_instance now in
  Alcotest.(check bool)
    "pending job with start_at in the future should not run"
    false
    actual;
  let job_instance =
    create_instance () None now job |> incr_tries |> incr_tries
  in
  let actual = Sihl_queue.should_run job_instance now in
  Alcotest.(check bool)
    "pending job with tries < max_tries should not run"
    true
    actual;
  let job_instance =
    create_instance () None now job |> incr_tries |> incr_tries |> incr_tries
  in
  let actual = Sihl_queue.should_run job_instance now in
  Alcotest.(check bool)
    "pending job with tries = max_tries should not run"
    false
    actual;
  let job_instance = create_instance () None now job in
  let job_instance = { job_instance with status = Sihl_queue.Failed } in
  let actual = Sihl_queue.should_run job_instance now in
  Alcotest.(check bool) "failed job should not run" false actual;
  let job_instance = create_instance () None now job in
  let job_instance = { job_instance with status = Sihl_queue.Succeeded } in
  let actual = Sihl_queue.should_run job_instance now in
  Alcotest.(check bool) "succeeded job should not run" false actual;
  let job_instance =
    create_instance () None now job |> update_next_run_at job.retry_delay
  in
  let actual = Sihl_queue.should_run job_instance now in
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
      Sihl_queue.create_job
        ~max_tries:3
        ~retry_delay:(Sihl.Time.Span.minutes 1)
        (fun _ -> Lwt_result.return (has_ran_job := true))
        (fun () -> "")
        (fun _ -> Ok ())
        "foo"
    in
    let service = QueueService.register ~jobs:[ Sihl_queue.hide job ] () in
    let* _ = Sihl.Container.start_services [ service ] in
    let* () = QueueService.dispatch () job in
    let* () = Lwt_unix.sleep 2.0 in
    let* () = Sihl.Container.stop_services [ service ] in
    let () = Alcotest.(check bool "has processed job" true !has_ran_job) in
    Lwt.return ()
  ;;

  let all_dispatched_jobs_gets_processed _ () =
    let processed_inputs = ref [] in
    let* () = Sihl.Container.stop_services [ QueueService.register () ] in
    let* () = Sihl.Cleaner.clean_all () in
    let job =
      Sihl_queue.create_job
        ~max_tries:3
        ~retry_delay:(Sihl.Time.Span.minutes 1)
        (fun input ->
          Lwt_result.return
            (processed_inputs := List.cons input !processed_inputs))
        (fun str -> str)
        (fun str -> Ok str)
        "foo"
    in
    let service = QueueService.register ~jobs:[ Sihl_queue.hide job ] () in
    let* _ = Sihl.Container.start_services [ service ] in
    let* () = QueueService.dispatch_all [ "three"; "two"; "one" ] job in
    let* () = Lwt_unix.sleep 4.0 in
    let* () = Sihl.Container.stop_services [ service ] in
    let () =
      Alcotest.(
        check
          (list string)
          "has processed inputs"
          [ "one"; "two"; "three" ]
          !processed_inputs)
    in
    Lwt.return ()
  ;;

  let two_dispatched_jobs_get_processed _ () =
    let has_ran_job1 = ref false in
    let has_ran_job2 = ref false in
    let* () = Sihl.Container.stop_services [ QueueService.register () ] in
    let* () = Sihl.Cleaner.clean_all () in
    let job1 =
      Sihl_queue.create_job
        ~max_tries:3
        ~retry_delay:(Sihl.Time.Span.minutes 1)
        (fun _ -> Lwt_result.return (has_ran_job1 := true))
        (fun () -> "")
        (fun _ -> Ok ())
        "foo1"
    in
    let job2 =
      Sihl_queue.create_job
        ~max_tries:3
        ~retry_delay:(Sihl.Time.Span.minutes 1)
        (fun _ -> Lwt_result.return (has_ran_job2 := true))
        (fun () -> "")
        (fun _ -> Ok ())
        "foo2"
    in
    let service =
      QueueService.register
        ~jobs:[ Sihl_queue.hide job1; Sihl_queue.hide job2 ]
        ()
    in
    let* _ = Sihl.Container.start_services [ service ] in
    let* () = QueueService.dispatch () job1 in
    let* () = QueueService.dispatch () job2 in
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
      Sihl_queue.create_job
        ~max_tries:3
        ~retry_delay:(Sihl.Time.Span.minutes 1)
        (fun _ -> Lwt_result.fail "didn't work")
        ~failed:(fun _ _ -> Lwt.return (has_cleaned_up_job := true))
        (fun () -> "")
        (fun _ -> Ok ())
        "foo"
    in
    let service = QueueService.register ~jobs:[ Sihl_queue.hide job ] () in
    let* _ = Sihl.Container.start_services [ service ] in
    let* () = QueueService.dispatch () job in
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
      Sihl_queue.create_job
        (fun _ -> failwith "didn't work")
        ~max_tries:3
        ~retry_delay:(Sihl.Time.Span.minutes 1)
        ~failed:(fun _ _ -> Lwt.return (has_cleaned_up_job := true))
        (fun () -> "")
        (fun _ -> Ok ())
        "foo"
    in
    let service = QueueService.register ~jobs:[ Sihl_queue.hide job ] () in
    let* _ = Sihl.Container.start_services [ service ] in
    let* () = QueueService.dispatch () job in
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
            "all dispatched jobs get processed"
            `Quick
            all_dispatched_jobs_gets_processed
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
