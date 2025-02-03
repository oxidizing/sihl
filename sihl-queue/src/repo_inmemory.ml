module Map = Map.Make (String)

let lifecycles = []
let state = ref Map.empty
let ordered_ids = ref []

let register_cleaner () =
  let cleaner ?ctx:_ _ =
    state := Map.empty;
    ordered_ids := [];
    Lwt.return ()
  in
  Sihl.Cleaner.register_cleaner cleaner
;;

let register_migration () = ()

let enqueue ?ctx:_ job_instance =
  let open Sihl.Contract.Queue in
  let id = job_instance.id in
  ordered_ids := List.cons id !ordered_ids;
  state := Map.add id job_instance !state;
  Lwt.return ()
;;

let enqueue_all ?ctx:_ job_instances =
  job_instances
  |> List.fold_left
       (fun res job -> Lwt.bind res (fun _ -> enqueue job))
       (Lwt.return ())
;;

let update ?ctx:_ job_instance =
  let open Sihl.Contract.Queue in
  let id = job_instance.id in
  state := Map.add id job_instance !state;
  Lwt.return ()
;;

let find_workable ?ctx:_ () =
  let all_job_instances =
    List.map (fun id -> Map.find_opt id !state) !ordered_ids
  in
  let now = Ptime_clock.now () in
  let rec filter_pending all_job_instances result =
    match all_job_instances with
    | Some job_instance :: job_instances ->
      if Sihl.Contract.Queue.should_run job_instance now
      then filter_pending job_instances (List.cons job_instance result)
      else filter_pending job_instances result
    | None :: job_instances -> filter_pending job_instances result
    | [] -> result
  in
  Lwt.return @@ filter_pending all_job_instances []
;;

let query ?ctx:_ () =
  Lwt.return @@ List.map (fun id -> Map.find id !state) !ordered_ids
;;

let find ?ctx:_ id = Lwt.return @@ Map.find_opt id !state

let delete ?ctx:_ (job : Sihl.Contract.Queue.instance) =
  state := Map.remove job.id !state;
  Lwt.return ()
;;

let search ?ctx:_ (sort : [ `Desc | `Asc ]) filter ~limit ~offset =
  let filtered =
    Map.filter
      (fun _ (job : Sihl.Contract.Queue.instance) ->
         Option.equal (fun t f -> CCString.find ~sub:f t > -1) job.tag filter)
      !state
    |> Map.to_seq
    |> List.of_seq
    |> List.map snd
    |> CCList.drop offset
    |> CCList.take limit
    |> CCList.sort
         (fun
             (j1 : Sihl.Contract.Queue.instance)
              (j2 : Sihl.Contract.Queue.instance)
            -> Option.compare String.compare j1.tag j2.tag)
    |> fun l -> if sort == `Desc then l else List.rev l
  in
  Lwt.return @@ (filtered, List.length filtered)
;;
