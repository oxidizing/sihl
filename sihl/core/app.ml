open Lwt.Syntax

let log_src = Logs.Src.create ~doc:"Sihl app" "sihl.app"

module Logger = (val Logs.src_log log_src : Logs.LOG)

type t =
  { services : Container.Service.t list
  ; before_start : Ctx.t -> unit Lwt.t
  ; after_start : Ctx.t -> unit Lwt.t
  ; before_stop : Ctx.t -> unit Lwt.t
  ; after_stop : Ctx.t -> unit Lwt.t
  }

let empty =
  { services = []
  ; before_start = (fun _ -> Lwt.return ())
  ; after_start = (fun _ -> Lwt.return ())
  ; before_stop = (fun _ -> Lwt.return ())
  ; after_stop = (fun _ -> Lwt.return ())
  }
;;

let with_services services app = { app with services }
let before_start before_start app = { app with before_start }
let after_start after_start app = { app with after_start }
let before_stop before_stop app = { app with before_stop }
let after_stop after_stop app = { app with after_stop }

(* TODO [jerben] 0. store ref to current app and start ctx 1. loop forever (in
   Lwt_main.run) 2. when command finishes, exit loop 3. when SIGINT comes, exit loop 4.
   call stop app let stop app ctx = let* () = app.before_stop ctx in print_endline "CORE:
   Stop services"; let* () = Container.stop_services ctx app.services in print_endline
   "CORE: Services stopped"; app.after_stop ctx *)

let starting_commands service =
  (* When executing a starting command, the service that publishes that command and all
     its dependencies is started before the command is run *)
  List.map
    (fun command ->
      let fn args =
        let* _ = Container.start_services [ service ] in
        command.Command.fn args
      in
      Command.{ command with fn })
    (Container.Service.commands service)
;;

let run
    ?(commands = [])
    ?(configuration = [])
    ?(log_reporter = Log.default_reporter)
    ?args
    app
  =
  (* Set the logger up as first thing so we can log *)
  Logs.set_reporter (log_reporter ());
  Logger.debug (fun m -> m "Setup service configurations");
  let configurations =
    List.map (fun service -> Container.Service.configuration service) app.services
  in
  List.iter
    (fun configuration -> configuration |> Configuration.data |> Configuration.store)
    configurations;
  Configuration.store configuration;
  let configuration_commands = Configuration.commands configurations in
  Logger.debug (fun m -> m "Setup service commands");
  let service_commands = app.services |> List.map starting_commands |> List.concat in
  let commands = List.concat [ configuration_commands; service_commands; commands ] in
  Lwt_main.run (Command.run commands args)
;;
