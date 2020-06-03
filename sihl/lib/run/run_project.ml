open Base

let ( let* ) = Lwt.bind

module type APP = sig
  val name : string

  val namespace : string

  val config : unit -> Core.Config.Schema.t

  val endpoints : unit -> Opium.App.builder list

  val repos : unit -> (module Core.Contract.REPOSITORY) list

  val bindings : unit -> Core.Registry.Binding.t list

  val commands : unit -> Core.Cmd.t list

  val start : unit -> (unit, string) Result.t

  val stop : unit -> (unit, string) Result.t
end

module type PROJECT = sig
  type t

  val create :
    ?bindings:Core.Registry.Binding.t list ->
    config:Core.Config.Setting.t ->
    (unit -> Opium_kernel.Rock.Middleware.t) list ->
    (module APP) list ->
    t

  val start : t -> (unit, string) Result.t Lwt.t

  val seed : t -> (unit, string) Result.t Lwt.t

  val migrate : t -> (unit, string) Result.t Lwt.t

  val clean : t -> (unit, string) Result.t Lwt.t

  val stop : t -> (unit, string) Result.t Lwt.t

  val run_command : t -> unit
end

module Project : PROJECT = struct
  type t = {
    apps : (module APP) list;
    middlewares : (unit -> Opium_kernel.Rock.Middleware.t) list;
    config : Core.Config.Setting.t;
    bindings : Core.Registry.Binding.t list option;
  }

  let app_names project =
    project.apps |> List.map ~f:(fun (module App : APP) -> App.namespace)

  let create ?bindings ~config middlewares apps =
    { apps; config; bindings; middlewares }

  let merge_endpoints project =
    project.apps
    |> List.map ~f:(fun (module App : APP) -> App.endpoints ())
    |> List.concat

  let add_builders builders app =
    List.fold ~f:(fun app builder -> builder app) ~init:app builders

  let start_http_server project =
    let endpoints = merge_endpoints project in
    let middlewares =
      List.map ~f:(fun m -> Opium.Std.middleware @@ m ()) project.middlewares
    in
    let port = Core.Config.read_int ~default:3000 "PORT" in
    Logs.debug (fun m -> m "START: Http server starting on port %i" port);

    let app =
      Opium.Std.App.empty |> Opium.Std.App.port port
      |> Opium.Std.App.cmd_name "Sihl Project"
      |> add_builders middlewares |> add_builders endpoints
    in
    (* detaching from the thread so tests can run in the same process *)
    let _ = Opium.Std.App.start app in
    Logs.debug (fun m -> m "START: Http server started");
    Lwt.return @@ Ok ()

  let setup_logger () =
    let log_level = Some Logs.Warning in
    Logs_fmt.reporter () |> Logs.set_reporter;
    Logs.set_level log_level;
    Logs.debug (fun m -> m "START: logger set up")

  let migrate project =
    project.apps
    |> List.map ~f:(fun (module App : APP) -> App.repos ())
    |> List.concat
    |> List.map ~f:(fun (module Repo : Core.Contract.REPOSITORY) ->
           Repo.migrate ())
    |> Repo.Migration.execute

  let bind_registry project =
    Logs.debug (fun m -> m "START: binding default implementations of apps");
    project.apps
    |> List.map ~f:(fun (module App : APP) ->
           List.map (App.bindings ()) ~f:Core.Registry.Binding.apply)
    |> ignore;
    Logs.debug (fun m -> m "START: binding project implementations");
    project.bindings
    |> Option.map ~f:(fun bindings ->
           List.map bindings ~f:Core.Registry.Binding.apply)
    |> ignore;
    Core.Registry.set_initialized ()

  let setup_config project =
    let schemas =
      project.apps |> List.map ~f:(fun (module App : APP) -> App.config ())
    in
    Core.Config.load_config schemas project.config

  let call_start_hooks project =
    let result =
      project.apps
      |> List.map ~f:(fun (module App : APP) ->
             App.start ()
             |> Result.map_error ~f:(fun err ->
                    [%string
                      "failure while calling start hook of app $(App.name) \
                       with $(err)"]))
      |> Result.all
    in
    match result with
    | Ok _ -> ()
    | Error msg ->
        Logs.err (fun m -> m "%s" msg);
        failwith msg

  let start project =
    (* Initialize random number generator *)
    Random.self_init ();
    setup_logger ();
    let apps = project |> app_names |> String.concat ~sep:", " in
    Logs.debug (fun m -> m "START: Setting up project with apps: %s" apps);
    Logs.debug (fun m -> m "START: Setting up configuration");
    setup_config project;
    Logs.debug (fun m -> m "START: Binding registry");
    bind_registry project;
    Logs.debug (fun m -> m "START: Calling app start hooks");
    call_start_hooks project;
    Logs.debug (fun m -> m "START: Starting HTTP server");
    start_http_server project

  (* TODO implement *)
  let seed _ = Lwt.return @@ Error "not implemented"

  let clean project =
    (* TODO move this into some repo related module *)
    let* request = Run_test.request_with_connection () in
    let repositories =
      project.apps
      |> List.map ~f:(fun (module App : APP) -> App.repos ())
      |> List.concat
    in
    Logs.debug (fun m -> m "REPO: Cleaning up app database");
    let rec clean_repos repos =
      match repos with
      | [] -> Lwt.return @@ Ok ()
      | (module Repo : Core.Contract.REPOSITORY) :: cleaners -> (
          let* result = Repo.clean |> Core.Db.query_db request in
          match result with
          | Ok _ -> clean_repos cleaners
          | Error msg ->
              Logs.err (fun m ->
                  m "REPO: Cleaning up app database failed %s" msg);
              Lwt.return @@ Error msg )
    in
    clean_repos repositories

  (* TODO implement *)
  let stop _ = Lwt.return @@ Error "not implemented"

  let add_default_commands project commands =
    List.concat
      [
        commands;
        [
          Core.Cmd.Builtin.Version.command;
          Core.Cmd.Builtin.Start.command (fun () -> start project);
          Core.Cmd.Builtin.Migrate.command (fun () -> migrate project);
        ];
      ]

  let is_testing () =
    Sys.getenv "SIHL_ENV"
    |> Option.value ~default:"development"
    |> String.equal "test"

  let run_command project =
    let args =
      Sys.get_argv () |> Array.to_list |> List.tl |> Option.value ~default:[]
    in
    (* if testing, silently do nothing *)
    if not @@ is_testing () then
      let () =
        Caml.print_string @@ "running command with args "
        ^ String.concat ~sep:", " args
        ^ "\n"
      in
      let () = setup_config project in
      let () = bind_registry project in

      let commands =
        project.apps
        |> List.map ~f:(fun (module App : APP) -> App.commands ())
        |> List.concat
        |> add_default_commands project
      in
      let command = Core.Cmd.find commands args in
      match command with
      | Some command ->
          let _ = Core.Cmd.execute command args in
          ()
      | None ->
          let help = Core.Cmd.help commands in
          Logs.debug (fun m -> m "%s" help)
    else
      Caml.print_string
      @@ "Running with SIHL_ENV=test, ignore command line arguments\n"
end
