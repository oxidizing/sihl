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
         routes
         |> List.map (fun (meth, route, handler) ->
                meth, Web.externalize_path route, handler)
         |> List.map to_opium_builder
         |> List.rev)
  |> List.concat
;;

let log_src = Logs.Src.create ("sihl.service." ^ Contract_http.name)

module Logs = (val Logs.src_log log_src : Logs.LOG)

type config = { port : int option }

let config port = { port }

let schema =
  let open Conformist in
  make
    [ optional
        ~meta:"The port the HTTP server listens on."
        (int ~default:3000 "PORT")
    ]
    config
;;

let registered_router = ref None
let registered_middlewares = ref []
let registered_not_found_handler = ref None
let started_server = ref None

let start_server () =
  Logs.debug (fun m -> m "Starting HTTP server");
  let port_nr =
    Option.value (Core_configuration.read schema).port ~default:33000
  in
  let app =
    Opium.App.(
      empty
      |> port port_nr
      |> cmd_name "Sihl App"
      |> fun app ->
      match !registered_not_found_handler with
      | Some not_found_handler -> app |> not_found not_found_handler
      | None -> app)
  in
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
  let%lwt server = Opium.App.start app in
  started_server := Some server;
  Lwt.return ()
;;

let routes_cmd =
  Core_command.make
    ~name:"routes"
    ~description:"Prints all HTTP routes"
    (fun _ ->
      !registered_router
      |> Option.map Web.routes_of_router
      |> Option.map
         @@ List.map (fun (meth, route, handler) ->
                meth, Web.externalize_path route, handler)
      |> Option.value ~default:[]
      |> List.map (fun (meth, path, _) ->
             let meth =
               Web.(
                 match meth with
                 | Get -> "GET"
                 | Head -> "HEAD"
                 | Options -> "OPTIONS"
                 | Post -> "POST"
                 | Put -> "PUT"
                 | Patch -> "PATCH"
                 | Delete -> "DELETE"
                 | Any -> "ANY")
             in
             Format.sprintf "%s %s" meth path)
      |> String.concat "\n"
      |> print_endline
      |> Option.some
      |> Lwt.return)
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

let register ?not_found_handler ?(middlewares = []) router =
  registered_router := Some router;
  registered_middlewares := middlewares;
  registered_not_found_handler := not_found_handler;
  let configuration = Core_configuration.make ~schema () in
  Core_container.Service.create
    ~configuration
    ~commands:[ routes_cmd ]
    ~server:true
    lifecycle
;;
