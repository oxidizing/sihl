open Alcotest_lwt
open Base

let ( let* ) = Lwt.bind

module Make
    (DbService : Sihl.Data.Db.Sig.SERVICE)
    (RepoService : Sihl.Data.Repo.Sig.SERVICE)
    (QueueService : Sihl.Queue.Sig.SERVICE) =
struct
  let queue_and_work_job _ () =
    let has_ran_job = ref false in
    let ctx = Sihl.Core.Ctx.empty |> DbService.add_pool in
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
    let* () = QueueService.dispatch ctx ~job () in
    let* () = QueueService.work_queue ctx ~jobs:[ job ] in
    let () = Alcotest.(check bool "has ran job" true !has_ran_job) in
    Lwt.return ()

  let test_suite =
    ("queue", [ test_case "queue and work job" `Quick queue_and_work_job ])
end
