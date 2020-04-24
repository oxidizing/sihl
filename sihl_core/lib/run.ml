open Core

let ( let* ) = Lwt.bind

module type APP = sig
  val name : string

  val namespace : string

  val config : Config.Schema.t

  val middlewares : Opium.App.builder list

  val migrations : Db.Migrate.migration

  val cleaners : (Db.connection -> unit Db.db_result) list

  val commands : My_command.t list
end

module type PROJECT = sig
  type t

  val create : config:Config.Setting.t -> (module APP) list -> t

  val start : t -> (unit, string) result Lwt.t

  val seed : t -> (unit, string) result Lwt.t

  val migrate : t -> (unit, string) result Lwt.t

  val clean : t -> (unit, string) result Lwt.t

  val stop : t -> (unit, string) result Lwt.t

  val run_command : t -> unit
end

module Project : PROJECT = struct
  open Opium.Std

  type t = { apps : (module APP) list; config : Config.Setting.t }

  let app_names project =
    project.apps |> List.map ~f:(fun (module App : APP) -> App.namespace)

  let create ~config apps = { apps; config }

  let merge_middlewares project =
    project.apps
    |> List.map ~f:(fun (module App : APP) -> App.middlewares)
    |> List.concat

  let add_middlewares middlewares app =
    List.fold ~f:(fun app route -> route app) ~init:app middlewares

  let start_http_server project =
    let middlewares = merge_middlewares project in
    let () = Logs.info (fun m -> m "http server starting") in
    let app =
      App.empty |> App.cmd_name "Project" |> Http.Middleware.handle_error
      |> Db.middleware
      |> add_middlewares middlewares
    in
    match App.run_command' app with
    | `Ok (_ : unit Lwt.t) ->
        let () = Logs.info (fun m -> m "http server started") in
        Lwt.return @@ Ok ()
    | `Error ->
        let () = Logs.err (fun m -> m "http server failed to start") in
        Lwt.return @@ Error "http server failed to start"
    | `Not_running ->
        let () = Logs.err (fun m -> m "http server failed to start") in
        Lwt.return @@ Error "http server failed to start"

  let setup_logger () =
    let log_level = Some Logs.Debug in
    let () = Logs_fmt.reporter () |> Logs.set_reporter in
    let () = Logs.set_level log_level in
    Logs.info (fun m -> m "logger set up")

  let migrate project =
    project.apps
    |> List.map ~f:(fun (module App : APP) -> App.migrations)
    |> Db.Migrate.execute

  let start project =
    let () = setup_logger () in
    let apps = project |> app_names |> String.concat ~sep:", " in
    let () = Logs.info (fun m -> m "project starting with apps: %s" apps) in
    let schemas =
      project.apps |> List.map ~f:(fun (module App : APP) -> App.config)
    in
    let () = Config.load_config schemas project.config in
    (* TODO run migrations here *)
    start_http_server project

  (* TODO implement *)
  let seed _ = Lwt.return @@ Error "not implemented"

  let clean project =
    let* request = Test.request_with_connection () in
    let cleaners =
      project.apps
      |> List.map ~f:(fun (module App : APP) -> App.cleaners)
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
    execute cleaners

  (* TODO implement *)
  let stop _ = Lwt.return @@ Error "not implemented"

  let add_default_commands project commands =
    List.concat
      [
        commands;
        [
          My_command.Builtin.Version.command;
          My_command.Builtin.Start.command (fun () -> start project);
        ];
      ]

  let run_command project =
    let args = Sys.get_argv () |> Array.to_list in
    (* if testing, silently do nothing *)
    if not @@ My_command.is_testing args then
      let commands =
        project.apps
        |> List.map ~f:(fun (module App : APP) -> App.commands)
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
          print_string help
end
