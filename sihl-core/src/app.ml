open Lwt.Syntax

let log_src = Logs.Src.create "sihl.app"

module Logger = (val Logs.src_log log_src : Logs.LOG)

exception Exception of string

type t =
  { services : Container.Service.t list
  ; before_start : unit -> unit Lwt.t
  ; after_stop : unit -> unit Lwt.t
  }

let empty =
  { services = []
  ; before_start = (fun _ -> Lwt.return ())
  ; after_stop = (fun _ -> Lwt.return ())
  }
;;

let with_services services app = { app with services }
let before_start before_start app = { app with before_start }
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

let start_cmd services =
  Command.make ~name:"start" ~help:"" ~description:"Start the Sihl app" (fun _ ->
      let normal_services =
        List.filter
          (function
            | service -> not (Container.Service.server service))
          services
      in
      let server_services = List.filter Container.Service.server services in
      match server_services with
      | [ server ] ->
        let* _ = Container.start_services normal_services in
        Container.Service.start server
      | [] ->
        Logger.err (fun m ->
            m
              "No 'server' service registered. Make sure that you have one server \
               service registered in your 'run.ml' such as a HTTP service");
        raise (Exception "No server service registered")
      | servers ->
        let names = List.map Container.Service.name servers in
        let names = String.concat ", " names in
        Logger.err (fun m ->
            m
              "Multiple server services registered: %s, you can only have one service \
               registered that is a 'server' service."
              names);
        raise (Exception "No server service registered"))
;;

let run' ?(commands = []) ?(log_reporter = Log.default_reporter) ?args app =
  (* Set the logger up as first thing so we can log *)
  Logs.set_reporter log_reporter;
  Logger.info (fun m -> m "Setup service configurations");
  let configurations =
    List.map
      (fun service ->
        Container.Service.name service, Container.Service.configuration service)
      app.services
  in
  let* file_configuration = Configuration.read_env_file () in
  Configuration.store @@ Option.value file_configuration ~default:[];
  let* () = app.before_start () in
  let configuration_commands = Configuration.commands configurations in
  Logger.info (fun m -> m "Setup service commands");
  let service_commands = app.services |> List.map starting_commands |> List.concat in
  let start_sihl_cmd = start_cmd app.services in
  let commands =
    List.concat [ [ start_sihl_cmd ]; configuration_commands; service_commands; commands ]
  in
  (* Make sure that the secret is valid *)
  let _ = Configuration.read_secret () in
  Command.run commands args
;;

let run ?(commands = []) ?(log_reporter = Log.default_reporter) ?args app =
  Lwt_main.run
  @@
  match args with
  | Some args -> run' ~commands ~log_reporter ~args app
  | None -> run' ~commands ~log_reporter app
;;
