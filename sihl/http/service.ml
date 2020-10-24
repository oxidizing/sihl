type meth =
  | Get
  | Post
  | Put
  | Delete
  | Any

type route = meth * string * (Opium_kernel.Request.t -> Opium_kernel.Response.t Lwt.t)

type router =
  { scope : string
  ; routes : route list
  ; middlewares : Opium_kernel.Rock.Middleware.t list
  }

let run_forever () =
  let p, _ = Lwt.wait () in
  p
;;

let prefix_route prefix (meth, path, handler) =
  (* TODO [jerben] Make this more robust, maybe regex based *)
  meth, Printf.sprintf "%s%s" prefix path, handler
;;

let route_to_opium_builder (meth, path, handler) =
  match meth with
  | Get -> Opium.Std.get path handler
  | Post -> Opium.Std.post path handler
  | Put -> Opium.Std.put path handler
  | Delete -> Opium.Std.delete path handler
  | Any -> Opium.Std.all path handler
;;

let apply_middleware_stack middleware_stack (meth, path, handler) =
  (* The request goes through the middleware stack from top to bottom, so we have to
     reverse the middleware stack *)
  let middleware_stack = List.rev middleware_stack in
  let wrapped_handler =
    List.fold_left
      (fun handler middleware -> Opium_kernel.Rock.Middleware.apply middleware handler)
      handler
      middleware_stack
  in
  meth, path, wrapped_handler
;;

let routers_to_opium_builders routers =
  routers
  |> List.map (fun { scope; routes; middlewares } ->
         routes
         |> List.map (prefix_route scope)
         |> List.map (apply_middleware_stack middlewares)
         |> List.map route_to_opium_builder)
  |> List.concat
;;

type config = { port : int option }

let config port = { port }

let schema =
  let open Conformist in
  make [ optional (int "PORT") ] config
;;

let routers = ref []

let start_server _ =
  Logs.debug (fun m -> m "WEB: Starting HTTP server");
  let port_nr = Option.value (Core.Configuration.read schema).port ~default:33000 in
  let app = Opium.Std.App.(empty |> port port_nr |> cmd_name "Sihl App") in
  let builders = routers_to_opium_builders !routers in
  let app = List.fold_left (fun app builder -> builder app) app builders in
  (* We don't want to block here, the returned Lwt.t will never resolve *)
  let _ = Opium.Std.App.start app in
  run_forever ()
;;

let start_cmd =
  Core.Command.make ~name:"start" ~help:"" ~description:"Start the web server" (fun _ ->
      let ctx = Core.Ctx.empty in
      start_server ctx)
;;

(* Lifecycle *)

let start ctx = Lwt.return ctx
let stop _ = Lwt.return ()
let lifecycle = Core.Container.Lifecycle.create "web-server" ~start ~stop

let configure rs configuration =
  routers := rs;
  let configuration = Core.Configuration.make ~schema configuration in
  Core.Container.Service.create ~configuration ~commands:[ start_cmd ] lifecycle
;;
