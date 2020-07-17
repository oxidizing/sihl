module Service : Cmd_sig.SERVICE = struct
  let on_init _ =
    (* TODO
       let add_default_commands project commands =
         List.concat
           [
             commands; [
               Core.Cmd.Builtin.Version.command;
               Core.Cmd.Builtin.Start.command (fun () -> start project);
               Core.Cmd.Builtin.Migrate.command (fun () -> migrate project);
             ];
           ]*)
    (*
 *
 *   let is_testing () =
 *     Sys.getenv "SIHL_ENV"
 *     |> Option.value ~default:"development"
 *     |> String.equal "test"
 *
 *   let run_command project =
 *     let args =
 *       Sys.get_argv () |> Array.to_list |> List.tl |> Option.value ~default:[]
 *     in
 *     (\* if testing, silently do nothing *\)
 *     if not @@ is_testing () then
 *       let () =
 *         Caml.print_string
 *         @@ Printf.sprintf "START: Running command with args %s\n"
 *              (String.concat ~sep:", " args)
 *       in
 *       let () = setup_config project in
 *       let () = bind_registry project in
 *
 *       let commands =
 *         project.apps
 *         |> List.map ~f:(fun (module App : APP) -> App.commands ())
 *         |> List.concat
 *         |> add_default_commands project
 *       in
 *       let command = Core.Cmd.find commands args in
 *       match command with
 *       | Some command ->
 *           let _ = Core.Cmd.execute command args in
 *           ()
 *       | None ->
 *           let help = Core.Cmd.help commands in
 *           Logs.debug (fun m -> m "%s" help)
 *     else
 *       Caml.print_string
 *       @@ "START: Running with SIHL_ENV=test, ignore command line arguments\n"
 *)
    Lwt_result.return ()

  let on_start _ = Lwt_result.return ()

  let on_stop _ = Lwt_result.return ()

  let register_commands _ = failwith "TODO register_commands"

  let run _ = failwith "TODO Sihl.Cmd.run()"
end
