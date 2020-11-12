module Core = Sihl_core

let log_src = Logs.Src.create "sihl.service.http"

module Logs = (val Logs.src_log log_src : Logs.LOG)

let to_opium_builder (meth, path, handler) =
  let open Route in
  match meth with
  | Get -> Opium.Std.get path handler
  | Post -> Opium.Std.post path handler
  | Put -> Opium.Std.put path handler
  | Delete -> Opium.Std.delete path handler
  | Any -> Opium.Std.all path handler
;;

let routers_to_opium_builders routers =
  routers
  |> List.map (fun router ->
         let routes = Route.router_to_routes router in
         List.map to_opium_builder routes)
  |> List.concat
;;

let run_forever () =
  let p, _ = Lwt.wait () in
  p
;;

type config = { port : int option }

let config port = { port }

let schema =
  let open Conformist in
  make [ optional (int ~default:3000 "PORT") ] config
;;

let registered_routers = ref []

let start_server _ =
  Logs.debug (fun m -> m "Starting HTTP server");
  let port_nr = Option.value (Core.Configuration.read schema).port ~default:33000 in
  let app = Opium.Std.App.(empty |> port port_nr |> cmd_name "Sihl App") in
  let builders = routers_to_opium_builders !registered_routers in
  let app = List.fold_left (fun app builder -> builder app) app builders in
  (* We don't want to block here, the returned Lwt.t will never resolve *)
  let _ = Opium.Std.App.start app in
  run_forever ()
;;

let start_cmd =
  Core.Command.make ~name:"start" ~help:"" ~description:"Start the web server" (fun _ ->
      let ctx = Core.Ctx.create () in
      start_server ctx)
;;

(* Lifecycle *)

let start ctx = Lwt.return ctx
let stop _ = Lwt.return ()
let lifecycle = Core.Container.Lifecycle.create "http" ~start ~stop

let register ?(routers = []) () =
  registered_routers := routers;
  let configuration = Core.Configuration.make ~schema () in
  Core.Container.Service.create ~configuration ~commands:[ start_cmd ] lifecycle
;;
