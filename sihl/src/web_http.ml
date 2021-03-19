include Contract_http

let to_opium_builder (meth, path, handler) =
  let open Web in
  match meth with
  | Get -> Opium.App.get path handler
  | Head -> Opium.App.head path handler
  | Options -> Opium.App.options path handler
  | Post -> Opium.App.post path handler
  | Patch -> Opium.App.patch path handler
  | Put -> Opium.App.put path handler
  | Delete -> Opium.App.delete path handler
  | Any -> Opium.App.all path handler
;;

let routers_to_opium_builders routers =
  let open Web in
  routers
  |> List.map (fun router ->
         let routes = routes_of_router router in
         routes |> List.map to_opium_builder |> List.rev)
  |> List.concat
;;

let log_src = Logs.Src.create ("sihl.service." ^ Contract_http.name)

module Logs = (val Logs.src_log log_src : Logs.LOG)

type config = { port : int option }

let config port = { port }

let schema =
  let open Conformist in
  make [ optional (int ~default:3000 "PORT") ] config
;;

let registered_router = ref None
let registered_middlewares = ref []
let started_server = ref None

let start_server () =
  let open Lwt.Syntax in
  Logs.debug (fun m -> m "Starting HTTP server");
  let port_nr =
    Option.value (Core_configuration.read schema).port ~default:33000
  in
  let app = Opium.App.(empty |> port port_nr |> cmd_name "Sihl App") in
  let middlewares = List.map Opium.App.middleware !registered_middlewares in
  (* Registered middlewares need to be mounted before routing happens, so that
     every single request goes through them, not only requests that match
     handlers *)
  let app = List.fold_left (fun app builder -> builder app) app middlewares in
  let router =
    match !registered_router with
    | None -> raise @@ Exception "No router registered"
    | Some router -> router
  in
  let builders = routers_to_opium_builders [ router ] in
  let app = List.fold_left (fun app builder -> builder app) app builders in
  (* We don't want to block here, the returned Lwt.t will never resolve *)
  let* server = Opium.App.start app in
  started_server := Some server;
  Lwt.return ()
;;

let start_cmd =
  Core_command.make
    ~name:"start-http"
    ~description:"Start the HTTP server"
    (fun _ -> start_server ())
;;

(* Lifecycle *)

let start () =
  (* Make sure that configuration is valid *)
  Core_configuration.require schema;
  start_server ()
;;

let stop () =
  match !started_server with
  | None ->
    Logs.warn (fun m -> m "The server is not running, nothing to stop");
    Lwt.return ()
  | Some server -> Lwt_io.shutdown_server server
;;

let lifecycle = Core_container.create_lifecycle "http" ~start ~stop

let register ?(middlewares = []) router =
  registered_router := Some router;
  registered_middlewares := middlewares;
  let configuration = Core_configuration.make ~schema () in
  Core_container.Service.create
    ~configuration
    ~commands:[ start_cmd ]
    ~server:true
    lifecycle
;;
