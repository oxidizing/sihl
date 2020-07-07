module Sig = App_sig

let ( let* ) = Lwt_result.bind

let kernel_services =
  [
    Utils.Random.Service.instance;
    Log.Service.instance;
    Config.Service.instance;
    Data.Db.Service.instance;
    Web.Server.Service.instance;
    Cmd.Service.instance;
    Schedule.Service.instance;
    Admin.Service.instance;
  ]

let run_forever () =
  let p, _ = Lwt.wait () in
  p

let start (module App : Sig.APP) =
  let result =
    (let ctx = Core.Ctx.empty in
     Log.debug (fun m -> m "APP: Bind services");
     let* () = Core.Container.bind_services ctx App.services in
     Log.debug (fun m -> m "APP: Register config");
     let* () = Config.register_config ctx App.config in
     let ctx = Data.Db.add_pool ctx in
     Log.debug (fun m -> m "APP: Run migrations");
     let* () = Data.Migration.run_all ctx in
     Log.debug (fun m -> m "APP: Register routes");
     let* () = Web.Server.register_routes ctx App.routes in
     Log.debug (fun m -> m "APP: Register commands");
     let* () = Cmd.register_commands ctx App.commands in
     Log.debug (fun m -> m "APP: Register schedules");
     let* () = Schedule.register_schedule ctx App.schedules in
     Log.debug (fun m -> m "APP: Register admin pages");
     let* () = Admin.register_pages ctx App.admin_pages in
     Log.debug (fun m -> m "APP: Start services");
     let* () = Core.Container.start_services ctx in
     App.on_start ctx)
    |> Lwt_result.map_err (fun msg ->
           Log.err (fun m -> m "APP: Failed to start app %s" msg);
           msg)
    |> Lwt.map Base.Result.ok_or_failwith
    |> Lwt.map (fun () -> Log.debug (fun m -> m "APP: App started"))
  in
  Lwt_main.run (Lwt.bind result run_forever)
