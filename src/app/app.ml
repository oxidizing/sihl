module Sig = App_sig

let ( let* ) = Lwt_result.bind

module Make (Kernel : Sig.KERNEL) (App : Sig.APP) = struct
  let start_app () =
    (let ctx = Core.Ctx.empty in
     Log.debug (fun m -> m "APP: Register services");
     let* () = Core.Container.register_services ctx App.services in
     Log.debug (fun m -> m "APP: Register config");
     let* () = Kernel.Config.register_config ctx App.config in
     let ctx = Kernel.Db.add_pool ctx in
     Log.debug (fun m -> m "APP: Register routes");
     let* () = Kernel.WebServer.register_routes ctx App.routes in
     Log.debug (fun m -> m "APP: Register commands");
     let* () = Kernel.Cmd.register_commands ctx App.commands in
     Log.debug (fun m -> m "APP: Register schedules");
     let* () = Kernel.Schedule.register_schedules ctx App.schedules in
     Log.debug (fun m -> m "APP: Start services");
     let* () = Core.Container.start_services ctx in
     App.on_start ctx)
    |> Lwt_result.map_err (fun msg ->
           Log.err (fun m -> m "APP: Failed to start app %s" msg);
           msg)
    |> Lwt.map Base.Result.ok_or_failwith

  let run () = Lwt_main.run (Lwt.bind (start_app ()) Kernel.Cmd.run)
end
