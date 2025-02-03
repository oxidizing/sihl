open Alcotest_lwt

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
  { id = Sihl.Random.Uuid.create ()
  ; name
  ; input
  ; tries = 0
  ; next_run_at
  ; max_tries
  ; status = Pending
  ; last_error = None
  ; last_error_at = None
  ; tag = None
  ; ctx = []
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
  Sihl.Configuration.store [ "QUEUE_FORCE_ASYNC", "true" ];
  let now = Ptime_clock.now () in
  let job =
    Sihl_queue.create_job
      (fun ?ctx:_ _ -> Lwt_result.return ())
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
  let search _ () =
    Sihl.Configuration.store [ "QUEUE_FORCE_ASYNC", "true" ];
    let%lwt () = Sihl.Container.stop_services [ QueueService.register () ] in
    let%lwt () = Sihl.Cleaner.clean_all () in
    let handle ?ctx:_ _ = Lwt_result.return () in
    let to_string () = "" in
    let of_string _ = Ok () in
    let job1 =
      Sihl_queue.create_job ~tag:"search123" handle to_string of_string "job1"
    in
    let job2 =
      Sihl_queue.create_job ~tag:"search567" handle to_string of_string "job2"
    in
    let job3 = Sihl_queue.create_job handle to_string of_string "job3" in
    let service =
      QueueService.register
        ~jobs:
          [ Sihl_queue.hide job1; Sihl_queue.hide job2; Sihl_queue.hide job3 ]
        ()
    in
    let%lwt (_ : Sihl.Container.lifecycle list) =
      Sihl.Container.start_services [ service ]
    in
    let%lwt () = QueueService.dispatch () job1 in
    let%lwt () = QueueService.dispatch () job2 in
    let%lwt () = QueueService.dispatch () job3 in
    let%lwt jobs = QueueService.search ~filter:"arch12" () in
    let%lwt () = Sihl.Container.stop_services [ service ] in
    match jobs with
    | [ _ ], n ->
      Alcotest.(check int) "there is exactly one match" 1 n;
      Lwt.return ()
    | res, _ ->
      failwith (Format.sprintf "found %d jobs instead of 1" (List.length res))
  ;;

  let dispatched_job_gets_processed _ () =
    Sihl.Configuration.store [ "QUEUE_FORCE_ASYNC", "true" ];
    let has_ran_job = ref false in
    let%lwt () = Sihl.Container.stop_services [ QueueService.register () ] in
    let%lwt () = Sihl.Cleaner.clean_all () in
    let job =
      Sihl_queue.create_job
        ~max_tries:3
        ~retry_delay:(Sihl.Time.Span.minutes 1)
        (fun ?(ctx = []) _ ->
           (match ctx with
            | [ ("pool", "test") ] -> ()
            | [] -> failwith "an empty ctx was provided, expected non-emtpy ctx"
            | _ -> failwith "ctx is not passed to job correctly");
           Lwt_result.return (has_ran_job := true))
        (fun () -> "")
        (fun _ -> Ok ())
        "foo"
    in
    let service = QueueService.register ~jobs:[ Sihl_queue.hide job ] () in
    let%lwt _ = Sihl.Container.start_services [ service ] in
    let%lwt () = QueueService.dispatch ~ctx:[ "pool", "test" ] () job in
    let%lwt () = Lwt_unix.sleep 2.0 in
    let%lwt () = Sihl.Container.stop_services [ service ] in
    let () = Alcotest.(check bool "has processed job" true !has_ran_job) in
    Lwt.return ()
  ;;

  let all_dispatched_jobs_gets_processed _ () =
    Sihl.Configuration.store [ "QUEUE_FORCE_ASYNC", "true" ];
    let processed_inputs = ref [] in
    let%lwt () = Sihl.Container.stop_services [ QueueService.register () ] in
    let%lwt () = Sihl.Cleaner.clean_all () in
    let job =
      Sihl_queue.create_job
        ~max_tries:3
        ~retry_delay:(Sihl.Time.Span.minutes 1)
        (fun ?ctx:_ input ->
           Lwt_result.return
             (processed_inputs := List.cons input !processed_inputs))
        (fun str -> str)
        (fun str -> Ok str)
        "foo"
    in
    let service = QueueService.register ~jobs:[ Sihl_queue.hide job ] () in
    let%lwt _ = Sihl.Container.start_services [ service ] in
    let%lwt () = QueueService.dispatch_all [ "three"; "two"; "one" ] job in
    let%lwt () = Lwt_unix.sleep 4.0 in
    let%lwt () = Sihl.Container.stop_services [ service ] in
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
    Sihl.Configuration.store [ "QUEUE_FORCE_ASYNC", "true" ];
    let has_ran_job1 = ref false in
    let has_ran_job2 = ref false in
    let%lwt () = Sihl.Container.stop_services [ QueueService.register () ] in
    let%lwt () = Sihl.Cleaner.clean_all () in
    let job1 =
      Sihl_queue.create_job
        ~max_tries:3
        ~retry_delay:(Sihl.Time.Span.minutes 1)
        (fun ?ctx:_ _ -> Lwt_result.return (has_ran_job1 := true))
        (fun () -> "")
        (fun _ -> Ok ())
        "foo1"
    in
    let job2 =
      Sihl_queue.create_job
        ~max_tries:3
        ~retry_delay:(Sihl.Time.Span.minutes 1)
        (fun ?ctx:_ _ -> Lwt_result.return (has_ran_job2 := true))
        (fun () -> "")
        (fun _ -> Ok ())
        "foo2"
    in
    let service =
      QueueService.register
        ~jobs:[ Sihl_queue.hide job1; Sihl_queue.hide job2 ]
        ()
    in
    let%lwt _ = Sihl.Container.start_services [ service ] in
    let%lwt () = QueueService.dispatch () job1 in
    let%lwt () = QueueService.dispatch () job2 in
    let%lwt () = Lwt_unix.sleep 4.0 in
    let%lwt () = Sihl.Container.stop_services [ service ] in
    let () = Alcotest.(check bool "has processed job1" true !has_ran_job1) in
    let () = Alcotest.(check bool "has processed job2" true !has_ran_job1) in
    Lwt.return ()
  ;;

  let cleans_up_job_after_error _ () =
    Sihl.Configuration.store [ "QUEUE_FORCE_ASYNC", "true" ];
    let has_cleaned_up_job = ref false in
    let%lwt () = Sihl.Container.stop_services [ QueueService.register () ] in
    let%lwt () = Sihl.Cleaner.clean_all () in
    let job =
      Sihl_queue.create_job
        ~max_tries:3
        ~retry_delay:(Sihl.Time.Span.minutes 1)
        (fun ?ctx:_ _ -> Lwt_result.fail "didn't work")
        ~failed:(fun ?ctx:_ _ _ -> Lwt.return (has_cleaned_up_job := true))
        (fun () -> "")
        (fun _ -> Ok ())
        "foo"
    in
    let service = QueueService.register ~jobs:[ Sihl_queue.hide job ] () in
    let%lwt _ = Sihl.Container.start_services [ service ] in
    let%lwt () = QueueService.dispatch () job in
    let%lwt () = Lwt_unix.sleep 2.0 in
    let%lwt () = Sihl.Container.stop_services [ service ] in
    let () =
      Alcotest.(check bool "has cleaned up job" true !has_cleaned_up_job)
    in
    Lwt.return ()
  ;;

  let cleans_up_job_after_exception _ () =
    Sihl.Configuration.store [ "QUEUE_FORCE_ASYNC", "true" ];
    let has_cleaned_up_job = ref false in
    let%lwt () = Sihl.Container.stop_services [ QueueService.register () ] in
    let%lwt () = Sihl.Cleaner.clean_all () in
    let job =
      Sihl_queue.create_job
        (fun ?ctx:_ _ -> failwith "didn't work")
        ~max_tries:3
        ~retry_delay:(Sihl.Time.Span.minutes 1)
        ~failed:(fun ?ctx:_ _ _ -> Lwt.return (has_cleaned_up_job := true))
        (fun () -> "")
        (fun _ -> Ok ())
        "foo"
    in
    let service = QueueService.register ~jobs:[ Sihl_queue.hide job ] () in
    let%lwt _ = Sihl.Container.start_services [ service ] in
    let%lwt () = QueueService.dispatch () job in
    let%lwt () = Lwt_unix.sleep 2.0 in
    let%lwt () = Sihl.Container.stop_services [ service ] in
    let () =
      Alcotest.(check bool "has cleaned up job" true !has_cleaned_up_job)
    in
    Lwt.return ()
  ;;

  let suite =
    [ ( "queue"
      , [ test_case "search jobs with tag" `Quick search
        ; test_case "should job run" `Quick should_run_job
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
