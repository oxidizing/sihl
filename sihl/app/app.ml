open Lwt.Syntax
module Sig = Sig

module Make
    (CommandService : Cmd.Service.Sig.SERVICE)
    (LogService : Log.Service.Sig.SERVICE) =
struct
  type t = {
    services : (module Core.Container.SERVICE) list;
    on_before_start : Core.Ctx.t -> unit Lwt.t;
    on_after_start : Core.Ctx.t -> unit Lwt.t;
    on_before_stop : Core.Ctx.t -> unit Lwt.t;
    on_after_stop : Core.Ctx.t -> unit Lwt.t;
  }

  let empty =
    {
      services = [];
      on_before_start = (fun _ -> Lwt.return ());
      on_after_start = (fun _ -> Lwt.return ());
      on_before_stop = (fun _ -> Lwt.return ());
      on_after_stop = (fun _ -> Lwt.return ());
    }

  let with_services services app = { app with services }

  let on_before_start on_before_start app = { app with on_before_start }

  let on_after_start on_after_start app = { app with on_after_start }

  let on_before_stop on_before_stop app = { app with on_before_stop }

  let on_after_stop on_after_stop app = { app with on_after_stop }

  let run app =
    Lwt_main.run
      (let ctx = Core.Ctx.empty in
       let* () = app.on_before_start ctx in
       LogService.debug (fun m -> m "APP: Start services");
       let services =
         List.concat
           [
             [
               (module LogService : Core.Container.SERVICE);
               (module CommandService : Core.Container.SERVICE);
             ];
             app.services;
           ]
       in
       let* _, ctx = Core.Container.start_services services in
       LogService.debug (fun m -> m "APP: Services started");
       let* () = app.on_after_start ctx in
       CommandService.run ())
end
