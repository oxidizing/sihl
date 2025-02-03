module type Sig = sig
  val lifecycle : Core_lifecycle.lifecycle
end

type t =
  { lifecycle : Core_lifecycle.lifecycle
  ; configuration : Core_configuration.t
  ; commands : Core_command.t list
  ; server : bool
  }
[@@deriving eq, show]

let commands (service : t) = service.commands
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
let stop t = t.lifecycle.stop ()
let id t = t.lifecycle.id
let name t = Core_lifecycle.human_name t.lifecycle

let start_services services =
  Logs.info (fun m -> m "Starting...");
  let lifecycles = List.map (fun service -> service.lifecycle) services in
  let lifecycles = lifecycles |> Core_lifecycle.top_sort_lifecycles in
  let%lwt () =
    Lwt_list.iter_s
      (fun (lifecycle : Core_lifecycle.lifecycle) ->
         Logs.debug (fun m ->
           m "Starting service: %s" @@ Core_lifecycle.human_name lifecycle);
         lifecycle.start ())
      lifecycles
  in
  Logs.info (fun m -> m "All services started.");
  Lwt.return lifecycles
;;

let stop_services services =
  Logs.info (fun m -> m "Stopping...");
  let lifecycles = List.map (fun service -> service.lifecycle) services in
  let lifecycles = lifecycles |> Core_lifecycle.top_sort_lifecycles in
  let%lwt () =
    Lwt_list.iter_s
      (fun (lifecycle : Core_lifecycle.lifecycle) ->
         Logs.debug (fun m ->
           m "Stopping service: %s" @@ Core_lifecycle.human_name lifecycle);
         lifecycle.stop ())
      lifecycles
  in
  Logs.info (fun m -> m "Stopped, Good Bye!");
  Lwt.return ()
;;
