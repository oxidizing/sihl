open Lwt.Syntax

let log_src = Logs.Src.create "sihl.core.container"
let () = Printexc.record_backtrace true

module Logs = (val Logs.src_log log_src : Logs.LOG)

exception Exception

type lifecycle =
  { name : string
  ; dependencies : unit -> lifecycle list
  ; start : unit -> unit Lwt.t
  ; stop : unit -> unit Lwt.t
  }

let create_lifecycle
    ?(dependencies = fun () -> [])
    ?(start = fun () -> Lwt.return ())
    ?(stop = fun () -> Lwt.return ())
    name
  =
  { name; dependencies; start; stop }
;;

module Service = struct
  module type Sig = sig
    val lifecycle : lifecycle
  end

  type t =
    { lifecycle : lifecycle
    ; configuration : Core_configuration.t
    ; commands : Core_command.t list
    ; server : bool
    }

  let commands service = service.commands
  let configuration service = service.configuration

  let create
      ?(commands = [])
      ?(configuration = Core_configuration.empty)
      ?(server = false)
      lifecycle
    =
    { lifecycle; configuration; commands; server }
  ;;

  let server t = t.server
  let start t = t.lifecycle.start ()
  let name t = t.lifecycle.name
end

module Map = Map.Make (String)

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
  |> List.map (fun lifecycle -> lifecycle.name, lifecycle)
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
             lifecycle.dependencies () |> List.map (fun dep -> dep.name)
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
             raise Exception)
  | Tsort.ErrorCycle remaining_names ->
    let msg = String.concat ", " remaining_names in
    Logs.err (fun m ->
        m
          "Cycle detected while starting services. These are the services \
           after the cycle: %s"
          msg);
    raise Exception
;;

let start_services services =
  Logs.info (fun m -> m "Starting...");
  let lifecycles =
    List.map (fun service -> service.Service.lifecycle) services
  in
  let lifecycles = lifecycles |> top_sort_lifecycles in
  let rec loop lifecycles =
    match lifecycles with
    | lifecycle :: lifecycles ->
      Logs.debug (fun m -> m "Starting service: %s" lifecycle.name);
      let f = lifecycle.start in
      let* () = f () in
      loop lifecycles
    | [] -> Lwt.return ()
  in
  let* () = loop lifecycles in
  Logs.info (fun m -> m "All services started.");
  Lwt.return lifecycles
;;

let stop_services services =
  Logs.info (fun m -> m "Stopping...");
  let lifecycles =
    List.map (fun service -> service.Service.lifecycle) services
  in
  let lifecycles = lifecycles |> top_sort_lifecycles in
  let rec loop lifecycles =
    match lifecycles with
    | lifecycle :: lifecycles ->
      Logs.debug (fun m -> m "Stopping service: %s" lifecycle.name);
      let f = lifecycle.stop in
      let* () = f () in
      loop lifecycles
    | [] -> Lwt.return ()
  in
  let* () = loop lifecycles in
  Logs.info (fun m -> m "Stopped, Good Bye!");
  Lwt.return ()
;;

let unpack name ?default service =
  match !service, default with
  | Some service, _ -> service
  | None, Some default -> default
  | None, None ->
    Logs.err (fun m ->
        m "%s was called before a service implementation was registered" name);
    Logs.info (fun m ->
        m
          "I was not able to find a default implementation either. Please make \
           sure to provide a implementation using \
           Sihl.Service.<Service>.register() of %s"
          name);
    print_endline
      "A service was called before it was registered. If you don't see any \
       other output, this means that you implemented a service facade \
       incorrectly. No log reporter was configured because this error happens \
       at module evaluation time";
    raise Exception
;;
