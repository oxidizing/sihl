let log_src = Logs.Src.create "sihl.core.container"
let () = Printexc.record_backtrace true

module Logs = (val Logs.src_log log_src : Logs.LOG)

exception Exception

(* TODO [aerben rename to t *)
type lifecycle =
  { type_name : string
  ; implementation_name : string
  ; id : int
  ; dependencies : unit -> lifecycle list
  ; start : unit -> unit Lwt.t
  ; stop : unit -> unit Lwt.t
  }

let counter = ref 0

let create_lifecycle
    ?(dependencies = fun () -> [])
    ?(start = fun () -> Lwt.return ())
    ?(stop = fun () -> Lwt.return ())
    ?implementation_name
    type_name
  =
  (* Give all lifecycles unique names *)
  counter := !counter + 1;
  let implementation_name =
    Option.value implementation_name ~default:type_name
  in
  { type_name; implementation_name; id = !counter; dependencies; start; stop }
;;

let human_name lifecycle =
  Format.asprintf "%s %s" lifecycle.type_name lifecycle.implementation_name
;;

module Map = Map.Make (Int)

let collect_all_lifecycles lifecycles =
  let rec collect_lifecycles lifecycle =
    match lifecycle.dependencies () with
    | [] -> [ lifecycle ]
    | lifecycles ->
      List.cons
        lifecycle
        (lifecycles
        |> List.map (fun lifecycle -> collect_lifecycles lifecycle)
        |> List.concat)
  in
  lifecycles
  |> List.map collect_lifecycles
  |> List.concat
  |> List.map (fun lifecycle -> lifecycle.id, lifecycle)
  |> List.to_seq
  |> Map.of_seq
;;

let top_sort_lifecycles lifecycles =
  let lifecycles = collect_all_lifecycles lifecycles in
  let lifecycle_graph =
    lifecycles
    |> Map.to_seq
    |> List.of_seq
    |> List.map (fun (id, lifecycle) ->
           let dependencies =
             lifecycle.dependencies () |> List.map (fun dep -> dep.id)
           in
           id, dependencies)
  in
  match Tsort.sort lifecycle_graph with
  | Tsort.Sorted sorted ->
    sorted
    |> List.map (fun id ->
           match Map.find_opt id lifecycles with
           | Some l -> l
           | None ->
             Logs.err (fun m -> m "Failed to sort lifecycles.");
             raise Exception)
  | Tsort.ErrorCycle remaining_ids ->
    let remaining_names =
      List.map
        (fun id -> lifecycles |> Map.find_opt id |> Option.map human_name)
        remaining_ids
      |> CCList.all_some
    in
    let msg = "Cycle detected while starting lifecycles." in
    let remaining_msg =
      Option.map
        (fun r ->
          Format.asprintf
            "%s These are the lifecycles after the cycle: %s"
            msg
            (String.concat ", " r))
        remaining_names
    in
    Logs.err (fun m -> m "%s" @@ Option.value remaining_msg ~default:msg);
    raise Exception
;;
