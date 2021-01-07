open Sihl_contract.Http

let log_src = Logs.Src.create ("sihl.service." ^ Sihl_contract.Http.name)

module Logs = (val Logs.src_log log_src : Logs.LOG)

let get path handler = Get, path, handler
let post path handler = Post, path, handler
let put path handler = Put, path, handler
let delete path handler = Delete, path, handler
let any path handler = Any, path, handler

let router ?(scope = "/") ?(middlewares = []) routes =
  { scope; routes; middlewares }
;;

let trailing_char s =
  let length = String.length s in
  try Some (String.sub s (length - 1) 1) with
  | _ -> None
;;

let tail s =
  try String.sub s 1 (String.length s - 1) with
  | _ -> ""
;;

let prefix prefix (meth, path, handler) =
  let path =
    match trailing_char prefix, Astring.String.head path with
    | Some "/", Some '/' -> Printf.sprintf "%s%s" prefix (tail path)
    | _, _ -> Printf.sprintf "%s%s" prefix path
  in
  meth, path, handler
;;

let apply_middleware_stack middleware_stack (meth, path, handler) =
  (* The request goes through the middleware stack from top to bottom, so we
     have to reverse the middleware stack *)
  let middleware_stack = List.rev middleware_stack in
  let wrapped_handler =
    List.fold_left
      (fun handler middleware -> Rock.Middleware.apply middleware handler)
      handler
      middleware_stack
  in
  meth, path, wrapped_handler
;;

let router_to_routes { scope; routes; middlewares } =
  routes
  |> List.map (prefix scope)
  |> List.map (apply_middleware_stack middlewares)
;;

let externalize_path ?prefix path =
  let prefix =
    match prefix, Sihl_core.Configuration.read_string "PREFIX_PATH" with
    | Some prefix, _ -> prefix
    | _, Some prefix -> prefix
    | _ -> ""
  in
  path
  |> String.split_on_char '/'
  |> List.cons prefix
  |> String.concat "/"
  |> Stringext.replace_all ~pattern:"//" ~with_:"/"
;;

let to_opium_builder (meth, path, handler) =
  let open Sihl_contract.Http in
  match meth with
  | Get -> Opium.App.get path handler
  | Post -> Opium.App.post path handler
  | Put -> Opium.App.put path handler
  | Delete -> Opium.App.delete path handler
  | Any -> Opium.App.all path handler
;;

let routers_to_opium_builders routers =
  routers
  |> List.map (fun router ->
         let routes = router_to_routes router in
         routes |> List.map to_opium_builder |> List.rev)
  |> List.concat
;;

type config = { port : int option }

let config port = { port }

let schema =
  let open Conformist in
  make [ optional (int ~default:3000 "PORT") ] config
;;

let registered_routers = ref []

let start_server () =
  let open Lwt.Syntax in
  Logs.debug (fun m -> m "Starting HTTP server");
  let port_nr =
    Option.value (Sihl_core.Configuration.read schema).port ~default:33000
  in
  let app = Opium.App.(empty |> port port_nr |> cmd_name "Sihl App") in
  let builders = routers_to_opium_builders !registered_routers in
  let app = List.fold_left (fun app builder -> builder app) app builders in
  (* We don't want to block here, the returned Lwt.t will never resolve *)
  let* _ = Opium.App.start app in
  Lwt.return ()
;;

let start_cmd =
  Sihl_core.Command.make
    ~name:"start-http"
    ~description:"Start the HTTP server"
    (fun _ -> start_server ())
;;

(* Lifecycle *)

let start () =
  (* Make sure that configuration is valid *)
  Sihl_core.Configuration.require schema;
  start_server ()
;;

let stop () = Lwt.return ()
let lifecycle = Sihl_core.Container.Lifecycle.create "http" ~start ~stop

let register ?(routers = []) () =
  registered_routers := routers;
  let configuration = Sihl_core.Configuration.make ~schema () in
  Sihl_core.Container.Service.create
    ~configuration
    ~commands:[ start_cmd ]
    ~server:true
    lifecycle
;;
