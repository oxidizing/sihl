open Alcotest_lwt
open Lwt.Syntax

let with_implementation (module Service : Sihl_contract.Queue.Sig) =
  let dispatched_job_gets_processed _ () =
    let has_ran_job = ref false in
    let* () =
      Sihl_core.Container.stop_services [ Sihl_facade.Queue.register (module Service) ]
    in
    let* () = Sihl_persistence.Repository.clean_all () in
    let job =
      Sihl_contract.Queue_job.create
        ~name:"foo"
        ~input_to_string:(fun _ -> None)
        ~string_to_input:(fun _ -> Ok ())
        ~handle:(fun ~input:_ -> Lwt_result.return (has_ran_job := true))
        ~failed:(fun _ -> Lwt_result.return ())
        ()
      |> Sihl_contract.Queue_job.set_max_tries 3
      |> Sihl_contract.Queue_job.set_retry_delay Sihl_core.Time.OneMinute
    in
    let service = Sihl_facade.Queue.register ~jobs:[ job ] (module Service) in
    let* _ = Sihl_core.Container.start_services [ service ] in
    let* () = Sihl_facade.Queue.dispatch ~job () in
    let* () = Lwt_unix.sleep 2.0 in
    let* () = Sihl_core.Container.stop_services [ service ] in
    let () = Alcotest.(check bool "has processed job" true !has_ran_job) in
    Lwt.return ()
  in
  let two_dispatched_jobs_get_processed _ () =
    let has_ran_job1 = ref false in
    let has_ran_job2 = ref false in
    let* () =
      Sihl_core.Container.stop_services [ Sihl_facade.Queue.register (module Service) ]
    in
    let* () = Sihl_persistence.Repository.clean_all () in
    let job1 =
      Sihl_contract.Queue_job.create
        ~name:"foo1"
        ~input_to_string:(fun _ -> None)
        ~string_to_input:(fun _ -> Ok ())
        ~handle:(fun ~input:_ -> Lwt_result.return (has_ran_job1 := true))
        ~failed:(fun _ -> Lwt_result.return ())
        ()
      |> Sihl_contract.Queue_job.set_max_tries 3
      |> Sihl_contract.Queue_job.set_retry_delay Sihl_core.Time.OneMinute
    in
    let job2 =
      Sihl_contract.Queue_job.create
        ~name:"foo2"
        ~input_to_string:(fun _ -> None)
        ~string_to_input:(fun _ -> Ok ())
        ~handle:(fun ~input:_ -> Lwt_result.return (has_ran_job2 := true))
        ~failed:(fun _ -> Lwt_result.return ())
        ()
      |> Sihl_contract.Queue_job.set_max_tries 3
      |> Sihl_contract.Queue_job.set_retry_delay Sihl_core.Time.OneMinute
    in
    let service = Sihl_facade.Queue.register ~jobs:[ job1; job2 ] (module Service) in
    let* _ = Sihl_core.Container.start_services [ service ] in
    let* () = Sihl_facade.Queue.dispatch ~job:job1 () in
    let* () = Sihl_facade.Queue.dispatch ~job:job2 () in
    let* () = Lwt_unix.sleep 4.0 in
    let* () = Sihl_core.Container.stop_services [ service ] in
    let () = Alcotest.(check bool "has processed job1" true !has_ran_job1) in
    let () = Alcotest.(check bool "has processed job2" true !has_ran_job1) in
    Lwt.return ()
  in
  let cleans_up_job_after_error _ () =
    let has_cleaned_up_job = ref false in
    let* () =
      Sihl_core.Container.stop_services [ Sihl_facade.Queue.register (module Service) ]
    in
    let* () = Sihl_persistence.Repository.clean_all () in
    let job =
      Sihl_contract.Queue_job.create
        ~name:"foo"
        ~input_to_string:(fun _ -> None)
        ~string_to_input:(fun _ -> Ok ())
        ~handle:(fun ~input:_ -> Lwt_result.fail "didn't work")
        ~failed:(fun _ -> Lwt_result.return (has_cleaned_up_job := true))
        ()
      |> Sihl_contract.Queue_job.set_max_tries 3
      |> Sihl_contract.Queue_job.set_retry_delay Sihl_core.Time.OneMinute
    in
    let service = Sihl_facade.Queue.register ~jobs:[ job ] (module Service) in
    let* _ = Sihl_core.Container.start_services [ service ] in
    let* () = Sihl_facade.Queue.dispatch ~job () in
    let* () = Lwt_unix.sleep 2.0 in
    let* () = Sihl_core.Container.stop_services [ service ] in
    let () = Alcotest.(check bool "has cleaned up job" true !has_cleaned_up_job) in
    Lwt.return ()
  in
  let cleans_up_job_after_exception _ () =
    let has_cleaned_up_job = ref false in
    let* () =
      Sihl_core.Container.stop_services [ Sihl_facade.Queue.register (module Service) ]
    in
    let* () = Sihl_persistence.Repository.clean_all () in
    let job =
      Sihl_contract.Queue_job.create
        ~name:"foo"
        ~input_to_string:(fun _ -> None)
        ~string_to_input:(fun _ -> Ok ())
        ~handle:(fun ~input:_ -> failwith "didn't work")
        ~failed:(fun _ -> Lwt_result.return (has_cleaned_up_job := true))
        ()
      |> Sihl_contract.Queue_job.set_max_tries 3
      |> Sihl_contract.Queue_job.set_retry_delay Sihl_core.Time.OneMinute
    in
    let service = Sihl_facade.Queue.register ~jobs:[ job ] (module Service) in
    let* _ = Sihl_core.Container.start_services [ service ] in
    let* () = Sihl_facade.Queue.dispatch ~job () in
    let* () = Lwt_unix.sleep 2.0 in
    let* () = Sihl_core.Container.stop_services [ service ] in
    let () = Alcotest.(check bool "has cleaned up job" true !has_cleaned_up_job) in
    Lwt.return ()
  in
  let suite =
    [ ( "queue"
      , [ test_case "dispatched job gets processed" `Quick dispatched_job_gets_processed
        ; test_case
            "two dispatched jobs get processed"
            `Quick
            two_dispatched_jobs_get_processed
        ; test_case "cleans up job after error" `Quick cleans_up_job_after_error
        ; test_case "cleans up job after exception" `Quick cleans_up_job_after_exception
        ] )
    ]
  in
  suite
;;
