open Lwt.Syntax
module Sig = App_sig

module Make (Kernel : Sig.KERNEL) = struct
  type t = {
    config : Config.t;
    endpoints : Web.Server.endpoint list;
    services : (module Core.Container.SERVICE) list;
    schedules : Schedule.t list;
    commands : Cmd.t list;
    on_start : Core.Ctx.t -> unit Lwt.t;
    on_stop : Core.Ctx.t -> unit Lwt.t;
  }

  let empty =
    {
      config = Config.create ~development:[] ~test:[] ~production:[];
      endpoints = [];
      services = [];
      schedules = [];
      commands = [];
      on_start = (fun _ -> Lwt.return ());
      on_stop = (fun _ -> Lwt.return ());
    }

  let with_config config app = { app with config }

  let with_endpoints endpoints app = { app with endpoints }

  let with_services services app = { app with services }

  let with_schedules schedules app = { app with schedules }

  let with_commands commands app = { app with commands }

  let on_start on_start app = { app with on_start }

  let on_stop on_stop app = { app with on_stop }

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
            Kernel.WebServer.start_server ctx
        | [] ->
            let ctx = Core.Ctx.empty in
            Kernel.WebServer.start_server ctx
        | _ -> failwith "Example usage: start with_migration")
      ()

  let run app =
    Lwt_main.run
      (let ctx = Core.Ctx.empty in
       Kernel.Log.debug (fun m -> m "APP: Register config");
       let* () = Kernel.Config.register_config ctx app.config in
       Kernel.Log.debug (fun m -> m "APP: Register routes");
       let* () = Kernel.WebServer.register_endpoints ctx app.endpoints in
       Kernel.Log.debug (fun m -> m "APP: Register commands");
       let commands = List.cons start_cmd app.commands in
       let* () = Kernel.Cmd.register_commands ctx commands in
       Kernel.Log.debug (fun m -> m "APP: Register schedules");
       let _ = app.schedules |> List.map (Kernel.Schedule.schedule ctx) in
       Kernel.Log.debug (fun m -> m "APP: Start services");
       let* _, ctx = Core.Container.start_services app.services in
       Kernel.Log.debug (fun m -> m "APP: Start app");
       let* () = app.on_start ctx in
       Kernel.Cmd.run ())
end
