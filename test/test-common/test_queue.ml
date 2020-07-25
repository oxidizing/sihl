open Alcotest_lwt
open Base

let ( let* ) = Lwt.bind

module Make
    (RepoService : Sihl.Data.Repo.Sig.SERVICE)
    (QueueService : Sihl.Queue.Sig.SERVICE) =
struct
  let dispatched_job_gets_processed ctx _ () =
    let has_ran_job = ref false in
    let* () = RepoService.clean_all ctx |> Lwt.map Result.ok_or_failwith in
    let job =
      Sihl.Queue.create_job ~name:"foo"
        ~input_to_string:(fun () -> None)
        ~string_to_input:(fun _ -> Ok ())
        ~handle:(fun _ ~input:_ -> Lwt_result.return (has_ran_job := true))
        ~failed:(fun _ -> Lwt_result.return ())
      |> Sihl.Queue.set_max_tries 3
      |> Sihl.Queue.set_retry_delay Sihl.Utils.Time.OneMinute
    in
    let* () = QueueService.register_jobs ctx ~jobs:[ job ] in
    let* () = QueueService.dispatch ctx ~job () in
    let* () = Lwt_unix.sleep 1.5 in
    let () = Alcotest.(check bool "has processed job" true !has_ran_job) in
    Lwt.return ()

  let test_suite ctx =
    ( "queue",
      [
        test_case "dispatched job gets processed" `Quick
          (dispatched_job_gets_processed ctx);
      ] )
end
