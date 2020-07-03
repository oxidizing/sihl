module Service : Cmd_sig.SERVICE = struct
  let on_bind _ =
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
    Lwt_result.return ()

  let on_start _ = Lwt_result.return ()

  let on_stop _ = Lwt_result.return ()

  let register_commands _ = failwith "TODO register_commands"
end

let instance =
  Core.Container.create_binding Cmd_sig.key (module Service) (module Service)
