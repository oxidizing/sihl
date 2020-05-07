open Base

let ( let* ) = Lwt.bind

module type APP = sig
  val name : string

  val namespace : string

  val config : unit -> Config.Schema.t

  val middlewares : unit -> Opium.App.builder list

  val migrations : unit -> Db.Migrate.migration

  val repositories : unit -> (Db.connection -> unit Db.db_result) list

  val bind : Registry.bind

  val commands : unit -> My_command.t list

  val start : unit -> (unit, string) Result.t

  val stop : unit -> (unit, string) Result.t
end

module type PROJECT = sig
  type t

  val create :
    ?bind:Registry.bind -> config:Config.Setting.t -> (module APP) list -> t

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
    config : Config.Setting.t;
    bind : Registry.bind option;
  }

  let app_names project =
    project.apps |> List.map ~f:(fun (module App : APP) -> App.namespace)

  let create ?bind ~config apps = { apps; config; bind }

  let merge_middlewares project =
    project.apps
    |> List.map ~f:(fun (module App : APP) -> App.middlewares ())
    |> List.concat

  let add_middlewares middlewares app =
    List.fold ~f:(fun app route -> route app) ~init:app middlewares

  let start_http_server project =
    let middlewares = merge_middlewares project in
    let () = Logs.info (fun m -> m "http server starting") in
    let static_files_path =
      Config.read_string ~default:"./static" "STATIC_FILES_DIR"
    in
    let app =
      Opium.Std.App.empty
      |> Opium.Std.App.cmd_name "Project"
      |> Opium.Std.middleware Opium.Std.Cookie.m
      |> Opium.Std.middleware
         @@ Opium.Std.Middleware.static ~local_path:static_files_path
              ~uri_prefix:"/assets" ()
      |> Middleware.flash |> Middleware.error |> Db.middleware
      |> add_middlewares middlewares
    in
    (* detaching from the thread so tests can run in the same process *)
    let _ = Opium.Std.App.start app in
    let () = Logs.info (fun m -> m "http server started") in
    Lwt.return @@ Ok ()

  let setup_logger () =
    let log_level = Some Logs.Debug in
    let () = Logs_fmt.reporter () |> Logs.set_reporter in
    let () = Logs.set_level log_level in
    Logs.info (fun m -> m "logger set up")

  let migrate project =
    project.apps
    |> List.map ~f:(fun (module App : APP) -> App.migrations ())
    |> Db.Migrate.execute

  let bind_registry project =
    (* TODO make it more explicit when binding core default implementations *)
    let () = Logs.info (fun m -> m "binding default core implementations") in
    let () =
      Registry.bind Contract.Migration.repository
        (module Db.Migrate.PostgresRepository)
    in
    let () = Logs.info (fun m -> m "binding default implementations of apps") in
    let _ =
      project.apps |> List.map ~f:(fun (module App : APP) -> App.bind ())
    in
    let () = Logs.info (fun m -> m "binding project implementations") in
    project.bind |> Option.map ~f:(fun bind -> bind ()) |> ignore

  let setup_config project =
    let schemas =
      project.apps |> List.map ~f:(fun (module App : APP) -> App.config ())
    in
    Config.load_config schemas project.config

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
    let () = setup_logger () in
    let apps = project |> app_names |> String.concat ~sep:", " in
    let () = Logs.info (fun m -> m "project starting with apps: %s" apps) in
    let () = setup_config project in
    let () = bind_registry project in
    let () = call_start_hooks project in
    (* TODO run migrations here? *)
    start_http_server project

  (* TODO implement *)
  let seed _ = Lwt.return @@ Error "not implemented"

  let clean project =
    let* request = Test.request_with_connection () in
    let repositories =
      project.apps
      |> List.map ~f:(fun (module App : APP) -> App.repositories ())
      |> List.concat
    in
    let () = Logs.info (fun m -> m "cleaning up app database") in
    let rec execute cleaners =
      match cleaners with
      | [] -> Lwt.return @@ Ok ()
      | cleaner :: cleaners -> (
          let* result = cleaner |> Db.query_db request in
          match result with
          | Ok _ -> execute cleaners
          | Error msg ->
              let () =
                Logs.err (fun m -> m "cleaning up app database failed: %s" msg)
              in
              Lwt.return @@ Error msg )
    in
    execute repositories

  (* TODO implement *)
  let stop _ = Lwt.return @@ Error "not implemented"

  let add_default_commands project commands =
    List.concat
      [
        commands;
        [
          My_command.Builtin.Version.command;
          My_command.Builtin.Start.command (fun () -> start project);
          My_command.Builtin.Migrate.command (fun () -> migrate project);
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
      in
      let () = setup_config project in
      let () = bind_registry project in

      let commands =
        project.apps
        |> List.map ~f:(fun (module App : APP) -> App.commands ())
        |> List.concat
        |> add_default_commands project
      in
      let command = My_command.find commands args in
      match command with
      | Some command ->
          let _ = My_command.execute command args in
          ()
      | None ->
          let help = My_command.help commands in
          Logs.info (fun m -> m "%s" help)
    else
      Caml.print_string
      @@ "running with SIHL_ENV=test, ignore command line arguments"
end
