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
  (* TODO hard code command init here *)
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
    | Failure _ ->
      (try Some (FileUtil.which "dune") with
      | Failure _ -> None)
  in
  match path_dune with
  | None -> run_init []
  | Some path_dune ->
    (match args with
    | _ :: "init" :: args ->
      (* We know that the init command is available *)
      run_init args
    | [ _ ] | [] ->
      (try
         Sihl.Config.root_path () |> ignore;
         forward_command path_dune []
       with
      | _ -> run_init [])
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
        else Sihl.Command.run ()))
;;
