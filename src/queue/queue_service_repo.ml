open Base
module Job = Queue_core.Job
module JobInstance = Queue_core.JobInstance

module Memory : Queue_sig.REPO = struct
  let state = ref (Map.empty (module String))

  let ordered_ids = ref []

  let clean _ =
    state := Map.empty (module String);
    ordered_ids := [];
    Lwt_result.return ()

  let migrate () = Data.Migration.empty "queue"

  let enqueue _ ~job_instance =
    let id = JobInstance.id job_instance |> Data.Id.to_string in
    ordered_ids := List.cons id !ordered_ids;
    state := Map.add_exn !state ~key:id ~data:job_instance;
    Lwt_result.return ()

  let update _ ~job_instance =
    let id = JobInstance.id job_instance |> Data.Id.to_string in
    state := Map.set !state ~key:id ~data:job_instance;
    Lwt_result.return ()

  let find_pending _ =
    let all_job_instances =
      List.map !ordered_ids ~f:(fun id -> Map.find !state id)
    in
    let rec filter_pending all_job_instances result =
      match all_job_instances with
      | Some job_instance :: job_instances ->
          if JobInstance.is_pending job_instance then
            filter_pending job_instances (List.cons job_instance result)
          else filter_pending job_instances result
      | None :: job_instances -> filter_pending job_instances result
      | [] -> result
    in
    Lwt_result.return @@ filter_pending all_job_instances []
end
