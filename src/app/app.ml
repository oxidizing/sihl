module Sig = App_sig

let ( let* ) = Lwt_result.bind

let start (module App : Sig.APP) =
  (let ctx = Core.Ctx.empty in
   let* () = Core.Container.bind_services ctx App.services in
   let* () = Config.register_config ctx App.config in
   let ctx = Data.Db.add_pool ctx in
   let* () = Data.Migration.run_all ctx in
   let* () = Web.Server.register_routes ctx App.routes in
   let* () = Cmd.register_commands ctx App.commands in
   let* () = Schedule.register_schedule ctx App.schedules in
   let* () = Admin.register_pages ctx App.admin_pages in
   let* () = Core.Container.start_services ctx in
   App.on_start ctx)
  |> Lwt_result.map_err (fun msg ->
         Log.err (fun m -> m "APP: Failed to start app %s" msg);
         msg)
  |> Lwt.map Base.Result.ok_or_failwith
  |> Lwt.map (fun _ ->
         Log.debug (fun m -> m "APP: App started");
         (module App : Sig.APP))

(* TODO
  RandomService: on_start should initialize
  WebService: on_start should start web server with routes
  CmdService: on_bind should add default commands
 *)
