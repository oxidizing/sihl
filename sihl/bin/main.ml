module M = Minicli.CLI

let forward_command path_dune args =
  let command =
    Format.sprintf
      "%s exec bin/bin.exe -- %s"
      path_dune
      (String.concat " " args)
  in
  let _ = Unix.system command in
  ()
;;

let run_init args =
  match Hashtbl.find_opt Sihl.Command.commands "init" with
  | None -> print_endline "could not find command init"
  | Some command ->
    let help = M.get_set_bool [ "--help" ] args in
    M.finalize ();
    if help
    then (
      print_endline command.description;
      print_endline @@ Format.sprintf "  %s" command.usage)
    else (
      try command.fn args with
      | Sihl.Command.Invalid_usage -> print_endline command.usage)
;;

let () =
  Printexc.record_backtrace true;
  let _, args = M.init () in
  let path_dune =
    try Some (Sihl.Config.bin_dune ()) with
    | _ ->
      (try Some (FileUtil.which "dune") with
      | _ -> None)
  in
  let path_app =
    try Some (Sihl.Config.bin_app_path ()) with
    | _ -> None
  in
  match path_dune, path_app with
  | _, None | None, _ -> run_init []
  | Some path_dune, Some path_app ->
    (match args with
    | _ :: "init" :: args ->
      (* We know that the init command is available *)
      run_init args
    | _ :: name :: args ->
      (* Everything else we forward to the app binary by default, after
         building *)
      (match Hashtbl.find_opt Sihl.Command.commands name with
      | None -> forward_command path_dune (List.cons name args)
      | Some command ->
        (* Stateful commands we have to forward, they depend on the state Sihl
           builds up *)
        if command.stateful
        then forward_command path_dune (List.cons name args)
        else Sihl.Command.run ())
    | [ _ ] | [] ->
      let _ = Unix.system (path_dune ^ " build") in
      if CCIO.File.exists path_app
      then forward_command path_dune []
      else run_init [])
;;
