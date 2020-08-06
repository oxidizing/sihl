module Sig = App_sig

let ( let* ) = Lwt_result.bind

module Make (Kernel : Sig.KERNEL) (App : Sig.APP) = struct
  let start_cmd =
    Cmd.make ~name:"start" ~help:"<with_migration>"
      ~description:
        "Start the Sihl app, use <with_migration> to optionally run the \
         migrations before starting the web server"
      ~fn:(fun args ->
        match args with
        | [ "with_migration" ] ->
            let ctx = Core.Ctx.empty |> Kernel.Db.add_pool in
            let* () = Kernel.Migration.run_all ctx in
            Kernel.WebServer.start_server ctx |> Lwt.map Result.ok
        | [] ->
            let ctx = Core.Ctx.empty in
            Kernel.WebServer.start_server ctx |> Lwt.map Result.ok
        | _ -> Lwt_result.fail "Example usage: start with_migration")
      ()

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
     let commands = List.cons start_cmd App.commands in
     let* () = Kernel.Cmd.register_commands ctx commands in
     Log.debug (fun m -> m "APP: Register schedules");
     let _ = App.schedules |> List.map (Kernel.Schedule.schedule ctx) in
     Log.debug (fun m -> m "APP: Start services");
     let* () = Core.Container.start_services ctx in
     Log.debug (fun m -> m "APP: Start app");
     let* () = App.on_start ctx in
     App.on_start ctx)
    |> Lwt_result.map_err (fun msg ->
           Log.err (fun m -> m "APP: Failed to start app %s" msg);
           msg)
    |> Lwt.map Base.Result.ok_or_failwith

  let run () = Lwt_main.run (Lwt.bind (start_app ()) Kernel.Cmd.run)
end
