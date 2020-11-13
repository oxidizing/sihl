open Lwt.Syntax

let log_src = Logs.Src.create "sihl.container"

module Logs = (val Logs.src_log log_src : Logs.LOG)

exception Exception of string

module Lifecycle = struct
  type start = unit -> unit Lwt.t
  type stop = unit -> unit Lwt.t

  type t =
    { name : string
    ; dependencies : t list
    ; start : start
    ; stop : stop
    }

  let name lifecycle = lifecycle.name
  let create ?(dependencies = []) name ~start ~stop = { name; dependencies; start; stop }
end

module Service = struct
  module type Sig = sig
    val lifecycle : Lifecycle.t
  end

  type t =
    { lifecycle : Lifecycle.t
    ; configuration : Configuration.t
    ; commands : Command.t list
    }

  let commands service = service.commands
  let configuration service = service.configuration

  let create ?(commands = []) ?(configuration = Configuration.empty) lifecycle =
    { lifecycle; configuration; commands }
  ;;
end

module Map = Map.Make (String)

let collect_all_lifecycles lifecycles =
  let rec collect_lifecycles lifecycle =
    match lifecycle.Lifecycle.dependencies with
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
  |> List.map (fun lifecycle -> lifecycle.Lifecycle.name, lifecycle)
  |> List.to_seq
  |> Map.of_seq
;;

let top_sort_lifecycles lifecycles =
  let lifecycles = collect_all_lifecycles lifecycles in
  let lifecycle_graph =
    lifecycles
    |> Map.to_seq
    |> List.of_seq
    |> List.map (fun (name, lifecycle) ->
           let dependencies =
             lifecycle.Lifecycle.dependencies |> List.map (fun dep -> dep.Lifecycle.name)
           in
           name, dependencies)
  in
  match Tsort.sort lifecycle_graph with
  | Tsort.Sorted sorted ->
    sorted
    |> List.map (fun name ->
           match Map.find_opt name lifecycles with
           | Some l -> l
           | None ->
             Logs.err (fun m -> m "Failed to sort lifecycle of: %s" name);
             raise (Exception "Dependency graph not sortable"))
  | Tsort.ErrorCycle remaining_names ->
    let msg = String.concat ", " remaining_names in
    raise
      (Exception
         ("Cycle detected while starting services. These are the services after the \
           cycle: "
         ^ msg))
;;

let start_services services =
  Logs.debug (fun m -> m "Starting Sihl");
  let lifecycles = List.map (fun service -> service.Service.lifecycle) services in
  let lifecycles = lifecycles |> top_sort_lifecycles in
  let rec loop lifecycles =
    match lifecycles with
    | lifecycle :: lifecycles ->
      Logs.debug (fun m -> m "Starting service: %s" lifecycle.Lifecycle.name);
      let f = lifecycle.start in
      let* () = f () in
      loop lifecycles
    | [] -> Lwt.return ()
  in
  let* () = loop lifecycles in
  Logs.debug (fun m -> m "All services online. Ready for Takeoff!");
  Lwt.return lifecycles
;;

let stop_services services =
  Logs.debug (fun m -> m "Stopping Sihl");
  let lifecycles = List.map (fun service -> service.Service.lifecycle) services in
  let lifecycles = lifecycles |> top_sort_lifecycles in
  let rec loop lifecycles =
    match lifecycles with
    | lifecycle :: lifecycles ->
      Logs.debug (fun m -> m "Stopping service: %s" lifecycle.Lifecycle.name);
      let f = lifecycle.stop in
      let* () = f () in
      loop lifecycles
    | [] -> Lwt.return ()
  in
  let* () = loop lifecycles in
  Logs.debug (fun m -> m "Stopped Sihl, Good Bye!");
  Lwt.return ()
;;
